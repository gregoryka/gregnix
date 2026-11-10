{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.gregnix) mkOpt mkSecretsWrapper;

  cfg = config.gregnix.programs.terminal.tools.jk;

  package = pkgs.gregnix.jk;

  needsWrapper = cfg.tokenSopsFile != null;

  jkWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "jk";
    executable = lib.getExe package;

    sopsEnv.JK_TOKEN = {
      sopsFile = cfg.tokenSopsFile;
      key = cfg.tokenSopsKey;
    };
  };

  # jk resolves its config via Go's `os.UserConfigDir()`, which on Darwin
  # is `~/Library/Application Support` rather than XDG.
  configFile =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/jk/config.yaml"
    else
      "${config.xdg.configHome}/jk/config.yaml";

  contextType = types.submodule {
    options = {
      url = mkOpt types.str "" ''
        Jenkins controller URL. Typically a `config.sops.placeholder.*`
        value, substituted at activation time by the sops template.
      '';
      username = mkOpt (types.nullOr types.str) null "Jenkins user ID (see `<url>/whoAmI/api/json`).";
    };
  };
in
{
  options.gregnix.programs.terminal.tools.jk = {
    enable = mkEnableOption "jk, a GitHub CLI-style client for Jenkins";

    contexts = mkOpt (types.attrsOf contextType) { } ''
      jk contexts, rendered into jk's `config.yaml` via a sops template
      (RAM-backed, never the Nix store). API tokens are *not* configured
      here: see `tokenSopsFile`, or store one in jk's secret store (the OS
      keychain), keyed by context name, with `jk auth login <url>
      --name <context> --username <user> --with-token` (token on stdin).
    '';

    activeContext = mkOpt (types.nullOr types.str) null "Context selected by default.";

    tokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding a Jenkins API token (see
      `tokenSopsKey`), exported as `JK_TOKEN` by a wrapper, decrypted fresh
      on every invocation. jk uses it for the selected context (`--context`,
      `JK_CONTEXT` or `activeContext`) without opening its secret store.
      For hosts without an OS keyring; leave `null` on Darwin, where jk
      keeps the token in its own Keychain item.
    '';

    tokenSopsKey = mkOpt types.str "jk_token" "Key within `tokenSopsFile` holding the token.";
  };

  config = mkIf cfg.enable {
    # The wrapper comes first so its `bin/jk` wins; `package` still
    # contributes the shell completions.
    home.packages = [
      (
        if needsWrapper then
          pkgs.symlinkJoin {
            name = "jk-${package.version}";
            paths = [
              jkWrapped
              package
            ];
          }
        else
          package
      )
    ];

    gregnix.programs.terminal.tools.claude-code.skills.jk = "${package}/share/jk/skills/jk";
    gregnix.programs.terminal.tools.devin.skills.jk = "${package}/share/jk/skills/jk";

    # `jk auth login` atomically replaces this symlink with a plain on-disk
    # copy (the token itself goes to the keychain, not this file);
    # sops-install-secrets removes that copy and restores the symlink on
    # the next activation.
    sops.templates."jk-config" = mkIf (cfg.contexts != { }) {
      path = configFile;
      content = lib.generators.toYAML { } (
        {
          version = 1;
          contexts = lib.mapAttrs (_: ctx: lib.filterAttrs (_: v: v != null) ctx) cfg.contexts;
        }
        // lib.optionalAttrs (cfg.activeContext != null) { active = cfg.activeContext; }
      );
    };
  };
}
