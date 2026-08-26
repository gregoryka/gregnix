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
    cfg.tokenRef != null
    || cfg.tokenSopsFile != null
    || cfg.enterpriseTokenRef != null
    || cfg.enterpriseTokenSopsFile != null;

  ghWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "gh";
    executable = lib.getExe pkgs.gh;

    # These are the only gh subcommands that print a token as their actual
    # output -- `auth token` by design, `auth git-credential` because it
    # speaks git's credential-helper protocol (a literal `password=<token>`
    # line back to git). Every other invocation stays masked.
    noMaskingCommands = [
      "auth token"
      "auth git-credential"
    ];

    opEnv =
      lib.optionalAttrs (cfg.tokenRef != null) {
        GH_TOKEN = cfg.tokenRef;
      }
      // lib.optionalAttrs (cfg.enterpriseTokenRef != null) {
        GH_ENTERPRISE_TOKEN = cfg.enterpriseTokenRef;
      };

    sopsEnv =
      lib.optionalAttrs (cfg.tokenSopsFile != null) {
        # `gh` reads `GH_TOKEN` natively for github.com auth -- see
        # https://cli.github.com/manual/gh_help_environment.
        GH_TOKEN = {
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

    tokenRef = mkOpt (types.nullOr types.str) null ''
      1Password reference (e.g. `op://Vault/item/field`) for a `GH_TOKEN`
      (github.com access). ARCHITECTURE.md's primary mechanism for CLI
      tool credentials: injected into the process environment via `op
      run` at invocation time, never written to disk or the Nix store.
    '';

    tokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the `GH_TOKEN` (see
      `tokenSopsKey`), for hosts without 1Password available.
      ARCHITECTURE.md's fallback: runtime sops decryption with Nix
      managing the wrapper. Set at most one of `tokenRef`/`tokenSopsFile`
      per host.
    '';

    tokenSopsKey = mkOpt types.str "gh_token" "Key within `tokenSopsFile` holding the token.";

    enterpriseTokenRef = mkOpt (types.nullOr types.str) null ''
      1Password reference (e.g. `op://Vault/item/field`) for a
      `GH_ENTERPRISE_TOKEN` (GitHub Enterprise access). Optional -- only
      needed on hosts that talk to a GHE instance.
    '';

    enterpriseTokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the `GH_ENTERPRISE_TOKEN`
      (see `enterpriseTokenSopsKey`), for hosts without 1Password
      available. Set at most one of
      `enterpriseTokenRef`/`enterpriseTokenSopsFile` per host.
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
