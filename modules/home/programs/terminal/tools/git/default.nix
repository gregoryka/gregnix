{
  config,
  lib,

  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkIf
    mkMerge
    mapAttrs'
    mapAttrsToList
    nameValuePair
    concatStringsSep
    flatten
    ;
  inherit (lib.gregnix) mkOpt;
  inherit (config.gregnix) user;

  cfg = config.gregnix.programs.terminal.tools.git;

  identityTemplateName = name: "git-identity-${name}";

  # For each identity's remotes, emit both the ssh (git@) and https
  # includeIf conditions pointing at that identity's rendered file.
  identityIncludes = flatten (
    mapAttrsToList (
      name: identity:
      let
        path = config.sops.templates.${identityTemplateName name}.path;
      in
      map (remote: ''
        [includeIf "hasconfig:remote.*.url:git@${remote}:*/**"]
          path = ${path}
        [includeIf "hasconfig:remote.*.url:https://${remote}/**"]
          path = ${path}
      '') identity.remotes
    ) cfg.identities
  );
in
{
  options.gregnix.programs.terminal.tools.git = {
    enable = mkEnableOption "Git";
    signByDefault = mkOpt types.bool true "Whether to sign commits by default.";
    userName = mkOpt types.str user.fullName "The name to configure git with.";

    identities = mkOpt (types.attrsOf (
      types.submodule {
        options = {
          remotes = mkOpt (types.listOf types.str) [ ] ''
            Remote hostnames to apply this identity to. Both the ssh
            (git@host) and https (https://host) forms are matched
            automatically via includeIf.
          '';
          email = mkOpt types.str "" "The `user.email` to use for this identity.";
          signingKey = mkOpt types.str "" ''
            The raw SSH public key (e.g. `ecdsa-sha2-nistp256 AAAA...`, no
            comment) used to sign as this identity. Used both for
            `user.signingKey` (prefixed with `key::`) and for this
            identity's line in the shared allowed-signers file.
          '';
          settings = mkOpt (types.attrsOf types.anything) { } ''
            Extra git config for this identity's repositories, rendered
            with `lib.generators.toGitINI` into its included file.
          '';
        };
      }
    )) { } "Per-remote git identities, applied via includeIf based on the remote URL.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.delta = {
        enable = true;
        enableGitIntegration = true;

        options = {
          dark = true;
          line-numbers = true;
          navigate = true;
          side-by-side = true;
        };
      };

      # Not wired up as the default git diff viewer (delta is); invoke on
      # demand via the `difft` alias below.
      programs.difftastic.enable = true;

      programs.git = {
        enable = true;

        settings = {
          alias.difft = "-c diff.external=difft diff";

          init.defaultBranch = "main";

          pull.rebase = true;

          push = {
            autoSetupRemote = true;
            default = "current";
          };

          rerere.enabled = true;

          user.name = cfg.userName;
        };

        signing = {
          format = "ssh";
          inherit (cfg) signByDefault;
        };
      };
    }

    (mkIf (cfg.identities != { }) {
      sops.templates =
        mapAttrs' (
          name: identity:
          nameValuePair (identityTemplateName name) {
            content = lib.generators.toGitINI (
              lib.recursiveUpdate {
                user = {
                  inherit (identity) email;
                  signingKey = "key::${identity.signingKey}";
                };
              } identity.settings
            );
          }
        ) cfg.identities
        // {
          "git-identities".content = concatStringsSep "\n" identityIncludes;
          # `gpg.ssh.allowedSignersFile` format: "<principal> <key-type> <key>".
          "git-allowed-signers".content = concatStringsSep "\n" (
            mapAttrsToList (_name: identity: "${identity.email} ${identity.signingKey}") cfg.identities
          );
        };

      programs.git = {
        includes = [ { path = config.sops.templates."git-identities".path; } ];
        settings.gpg.ssh.allowedSignersFile = config.sops.templates."git-allowed-signers".path;
      };
    })
  ]);
}
