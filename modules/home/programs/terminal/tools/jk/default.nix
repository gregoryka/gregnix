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

  needsWrapper = cfg.keyringPassphraseSopsFile != null;

  # jk has no environment variable for the API token itself, only for the
  # passphrase of its encrypted file store -- so on hosts without an OS
  # keyring the token lives in that store, unlocked by a sops-held
  # passphrase on every invocation.
  jkWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "jk";
    executable = lib.getExe package;

    env.JK_ALLOW_INSECURE_STORE = "1";

    sopsEnv.JK_KEYRING_PASSPHRASE = {
      sopsFile = cfg.keyringPassphraseSopsFile;
      key = cfg.keyringPassphraseSopsKey;
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
      here: jk only reads them from its secret store (the OS keychain,
      or the encrypted file store with `keyringPassphraseSopsFile`),
      keyed by context name -- store one with `jk auth login <url>
      --name <context> --username <user> --with-token` (token on stdin).
    '';

    activeContext = mkOpt (types.nullOr types.str) null "Context selected by default.";

    keyringPassphraseSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the passphrase for jk's
      encrypted file store (see `keyringPassphraseSopsKey`), exported as
      `JK_KEYRING_PASSPHRASE` alongside `JK_ALLOW_INSECURE_STORE=1` by a
      wrapper, decrypted fresh on every invocation. Linux-only, for hosts
      without an OS keyring; on Darwin jk keeps the token in its own
      Keychain item instead.
    '';

    keyringPassphraseSopsKey =
      mkOpt types.str "jk_keyring_passphrase"
        "Key within `keyringPassphraseSopsFile` holding the passphrase.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(pkgs.stdenv.hostPlatform.isDarwin && needsWrapper);
        message = "gregnix.programs.terminal.tools.jk.keyringPassphraseSopsFile is Linux-only; on Darwin jk uses its Keychain item.";
      }
    ];

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
