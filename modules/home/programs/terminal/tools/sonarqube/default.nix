{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.gregnix) mkOpt mkSecretsWrapper;

  cfg = config.gregnix.programs.terminal.tools.sonarqube;

  package = pkgs.gregnix.sonarqube-cli;
  secrets = pkgs.gregnix.sonar-secrets;
  agentPlugins = pkgs.gregnix.sonarqube-agent-plugins;

  agentPluginFiles =
    kind: names: suffix:
    lib.genAttrs names (name: "${agentPlugins}/share/sonarqube-agent-plugins/${kind}/${name}${suffix}");
  agentSkills = agentPluginFiles "skills" agentPlugins.skillNames "";

  # The CLI only honours `SONARQUBE_CLI_SERVER` when paired with
  # `SONARQUBE_CLI_TOKEN` (otherwise it falls back to the keychain
  # connection from `sonar auth login`) -- see
  # https://docs.sonarsource.com/sonarqube-cli/using-sonarqube-cli/environment-variables.
  # Without a sops token, ship the vendor-signed binary unwrapped so its
  # own keychain item (see ARCHITECTURE.md) is used.
  needsWrapper = cfg.tokenSopsFile != null;

  sonarWrapped = mkSecretsWrapper {
    inherit pkgs;
    name = "sonar";
    executable = lib.getExe package;

    sopsEnv = {
      SONARQUBE_CLI_TOKEN = {
        sopsFile = cfg.tokenSopsFile;
        key = cfg.tokenSopsKey;
      };
    }
    // lib.optionalAttrs (cfg.serverUrlSopsFile != null) {
      SONARQUBE_CLI_SERVER = {
        sopsFile = cfg.serverUrlSopsFile;
        key = cfg.serverUrlSopsKey;
      };
    };
  };

  # The hooks authenticate like any other command (they block without a
  # connection), so they run through the same wrapper.
  sonar = if needsWrapper then sonarWrapped else package;

  mkSecretsHook = event: matcher: subcommand: {
    inherit event matcher;
    command = "${lib.getExe sonar} hook ${subcommand}";
    timeout = 60;
    replaces = [ "sonar-secrets" ];
  };
in
{
  options.gregnix.programs.terminal.tools.sonarqube = {
    enable = mkEnableOption "the SonarQube CLI (`sonar`)";

    serverUrlSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding the SonarQube Server URL (see
      `serverUrlSopsKey`), exported as `SONARQUBE_CLI_SERVER` alongside
      `tokenSopsFile` (ignored without it). Decrypted at invocation time
      by the wrapper -- never rendered to disk. Leave `null` for
      SonarQube Cloud.
    '';

    serverUrlSopsKey =
      mkOpt types.str "sonarqube_server_url"
        "Key within `serverUrlSopsFile` holding the URL.";

    tokenSopsFile = mkOpt (types.nullOr types.path) null ''
      Path to a sops-encrypted file holding a SonarQube *user* token (see
      `tokenSopsKey`), exported as `SONARQUBE_CLI_TOKEN`. ARCHITECTURE.md's
      mechanism for CLI tool credentials: runtime sops decryption with Nix
      managing the wrapper, injected into the process environment at
      invocation time, never written to disk or the Nix store. Leave
      `null` to authenticate via `sonar auth login` and the system
      keychain instead.
    '';

    tokenSopsKey = mkOpt types.str "sonarqube_token" "Key within `tokenSopsFile` holding the token.";

    settings =
      mkOpt (types.attrsOf (types.either types.bool types.str))
        {
          "telemetry.enabled" = false;
          "stats.enabled" = false;
        }
        ''
          CLI settings written to `~/.sonar/sonarqube-cli/cli-config.properties`
          (what `sonar config set` would otherwise manage). The file is a
          read-only store link, so `sonar config set` fails while this is
          non-empty. Defaults opt out of usage telemetry sent to SonarSource
          and of the local per-scan stats ledger.
        '';
  };

  config = mkIf cfg.enable {
    home.packages = [ sonar ];

    gregnix.programs.terminal.tools = {
      claude-code = {
        skills = agentSkills;
        agents = agentPluginFiles "agents" agentPlugins.agentNames ".md";
        # The hooks `sonar integrate` would install, minus the
        # `command -v sonar || exit 0` guard of its scripts. `replaces` drops
        # that command's own entries, should it ever be run.
        hooks = {
          sonar-secrets-pre-tool-use = mkSecretsHook "PreToolUse" "Read" "claude-pre-tool-use";
          sonar-secrets-prompt-submit = mkSecretsHook "UserPromptSubmit" "*" "claude-prompt-submit";
        };
      };
      devin = {
        skills = agentSkills;
        agents = agentPluginFiles "devin/agents" agentPlugins.agentNames ".md";
        hooks = {
          sonar-secrets-pre-tool-use = mkSecretsHook "PreToolUse" "^read$" "devin-pre-tool-use";
          sonar-secrets-prompt-submit = mkSecretsHook "UserPromptSubmit" "" "devin-prompt-submit";
        };
      };
    };

    home.file = {
      ".sonar/sonarqube-cli/cli-config.properties" = mkIf (cfg.settings != { }) {
        text = lib.generators.toKeyValue { } cfg.settings;
      };

      ".sonar/sonarqube-cli/bin/${secrets.cliBinaryName}" =
        mkIf (lib.meta.availableOn pkgs.stdenv.hostPlatform secrets)
          { source = lib.getExe secrets; };
    };
  };
}
