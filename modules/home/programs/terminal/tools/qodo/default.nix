{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.gregnix) mkOpt mkSecretsWrapper;

  cfg = config.gregnix.programs.terminal.tools.qodo;

  # `pkgs.gregnix.qodo-cli-skills.skillNames` (a plain Nix list, not
  # discovered via `builtins.readDir`) is the single source of truth for
  # these names -- see that package's comment for why avoiding
  # import-from-derivation here matters. `genAttrs` below just builds
  # name -> directory mappings by string concatenation, which is pure and
  # doesn't force building either output.
  mkSkillEntries = dir: lib.genAttrs pkgs.gregnix.qodo-cli-skills.skillNames (name: "${dir}/${name}");

  needsWrapper = cfg.sdkUrlSopsFile != null || cfg.tokenSopsFile != null;

  qodoWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "qodo";
    executable = lib.getExe pkgs.gregnix.qodo-cli;

    sopsEnv =
      lib.optionalAttrs (cfg.sdkUrlSopsFile != null) {
        # `resolveCredentials()` in qodo.mjs pairs `QODO_BASE_URL` with a
        # token for fully non-interactive use. This is the self-hosted
        # platform's *SDK* endpoint -- a distinct host from the auth/login
        # endpoint (see `resolveAuthUrl()`), which `qodo login` discovers
        # for itself during the device-code handshake and isn't managed
        # here.
        QODO_BASE_URL = {
          sopsFile = cfg.sdkUrlSopsFile;
          key = cfg.sdkUrlSopsKey;
        };
      }
      // lib.optionalAttrs (cfg.tokenSopsFile != null) {
        QODO_API_KEY = {
          sopsFile = cfg.tokenSopsFile;
          key = cfg.tokenSopsKey;
        };
      };
  };
in
{
  options.gregnix.programs.terminal.tools.qodo = {
    enable = mkEnableOption "the Qodo CLI";

    sdkUrlSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the self-hosted Qodo *SDK*
      URL (see `sdkUrlSopsKey`) -- the endpoint `resolveCredentials()` in
      qodo.mjs pairs with a token for fully non-interactive use. This is
      not the auth/login endpoint: `qodo login`'s device-code handshake
      discovers and stores that (and the SDK URL it's paired with) on its
      own, so it isn't configured here. Decrypted at invocation time by
      the wrapper -- never rendered to disk. Leave `null` for Qodo's
      public cloud.
    '';

    sdkUrlSopsKey = mkOpt types.str "qodo_sdk_url" "Key within `sdkUrlSopsFile` holding the URL.";

    tokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the Qodo API token (see
      `tokenSopsKey`). ARCHITECTURE.md's mechanism for CLI tool
      credentials: runtime sops decryption with Nix managing the wrapper,
      injected into the process environment at invocation time, never
      written to disk or the Nix store.
    '';

    tokenSopsKey = mkOpt types.str "qodo_token" "Key within `tokenSopsFile` holding the token.";
  };

  config = mkIf cfg.enable {
    home.packages = [ (if needsWrapper then qodoWrapped else pkgs.gregnix.qodo-cli) ];

    # Contribute Qodo's bundled skills declaratively (rather than
    # `qodo skills install` at activation time) via each agent tool
    # module's own merge point -- they own their config directories, qodo
    # only feeds into them.
    gregnix.programs.terminal.tools.claude-code.skills =
      mkSkillEntries pkgs.gregnix.qodo-cli-skills.claudeCode;
    gregnix.programs.terminal.tools.devin.skills = mkSkillEntries pkgs.gregnix.qodo-cli-skills.devin;
  };
}
