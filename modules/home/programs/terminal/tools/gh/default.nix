{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  inherit (lib.gregnix) mkOpt mkSecretsWrapper;

  cfg = config.gregnix.programs.terminal.tools.gh;

  needsWrapper =
    cfg.tokenSopsFile != null || cfg.enterpriseTokenSopsFile != null || cfg.gitEmailTokens != { };

  # `git-email-is EMAIL [IGNORED...]`: whether the current repository's
  # `user.email` (i.e. its git identity) is EMAIL.
  gitEmailIs = pkgs.writeShellScript "git-email-is" ''
    [[ "$(${lib.getExe pkgs.git} config user.email)" == "$1" ]]
  '';

  ghWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "gh";
    executable = lib.getExe pkgs.gh;

    sopsEnv =
      lib.optionalAttrs (cfg.tokenSopsFile != null || cfg.gitEmailTokens != { }) {
        # `gh` reads `GH_TOKEN` natively for github.com auth -- see
        # https://cli.github.com/manual/gh_help_environment.
        GH_TOKEN =
          lib.mapAttrsToList (_name: entry: {
            inherit (entry) sopsFile key;
            when = "${gitEmailIs} ${lib.escapeShellArg entry.email}";
          }) cfg.gitEmailTokens
          ++ lib.optional (cfg.tokenSopsFile != null) {
            sopsFile = cfg.tokenSopsFile;
            key = cfg.tokenSopsKey;
          };
      }
      // lib.optionalAttrs (cfg.enterpriseTokenSopsFile != null) {
        # `GH_ENTERPRISE_TOKEN` is the equivalent for a GitHub Enterprise
        # host; optional since not every host talks to a GHE instance.
        GH_ENTERPRISE_TOKEN = {
          sopsFile = cfg.enterpriseTokenSopsFile;
          key = cfg.enterpriseTokenSopsKey;
        };
      };
  };
in
{
  options.gregnix.programs.terminal.tools.gh = {
    enable = mkEnableOption "the gh CLI tool";

    gitCredentialHelper = {
      hosts = mkOption {
        type = types.listOf types.str;
        default = [
          "https://github.com"
          "https://gist.github.com"
        ];
        description = "A list of hosts for which gh should be used as a credential helper.";
      };
    };

    tokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the default `GH_TOKEN`
      (github.com access, see `tokenSopsKey`), used unless a
      `gitEmailTokens` entry matches. ARCHITECTURE.md's mechanism for CLI
      tool credentials: runtime sops decryption with Nix managing the
      wrapper, injected into the process environment at invocation time,
      never written to disk or the Nix store.
    '';

    tokenSopsKey = mkOpt types.str "gh_token" "Key within `tokenSopsFile` holding the token.";

    gitEmailTokens =
      mkOpt
        (types.attrsOf (
          types.submodule {
            options = {
              email = mkOption {
                type = types.str;
                description = ''
                  `user.email` (e.g. a git identity's) of the current
                  repository that selects this token.
                '';
              };
              sopsFile = mkOption {
                type = types.path;
                description = "Path to a sops-encrypted file holding this `GH_TOKEN`.";
              };
              key = mkOpt types.str "gh_token" "Key within `sopsFile` holding the token.";
            };
          }
        ))
        { }
        "`GH_TOKEN`s to use instead of `tokenSopsFile` in repositories committing as `email`; the first matching entry (by name) wins.";

    enterpriseTokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the `GH_ENTERPRISE_TOKEN`
      (GitHub Enterprise access, see `enterpriseTokenSopsKey`). Optional
      -- only needed on hosts that talk to a GHE instance.
    '';

    enterpriseTokenSopsKey =
      mkOpt types.str "gh_enterprise_token"
        "Key within `enterpriseTokenSopsFile` holding the token.";
  };

  config = mkIf cfg.enable {
    programs.gh = {
      enable = true;
      package = if needsWrapper then ghWrapped else pkgs.gh;

      gitCredentialHelper = {
        enable = true;
        inherit (cfg.gitCredentialHelper) hosts;
      };

      settings = {
        version = "1";
        git_protocol = "ssh";
        telemetry = "disabled";
      };
    };
  };
}
