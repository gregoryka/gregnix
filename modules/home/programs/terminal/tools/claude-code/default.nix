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

  inherit (lib.gregnix) mkAgentHooksMerge mkAgentHooksOption;

  cfg = config.gregnix.programs.terminal.tools.claude-code;
in
{
  options.gregnix.programs.terminal.tools.claude-code = {
    enable = mkEnableOption "Claude Code config management (skills, etc.)";

    # `attrsOf` merges natively across module definitions -- unlike
    # home-manager's `programs.claude-code.skills` (a single value: either
    # one attrset or one directory path), this can be assigned piecemeal by
    # separate tool modules (e.g. qodo) without them stepping on each
    # other or on this module directly.
    #
    # Kept as name -> directory (not `skillDirs` + `builtins.readDir`
    # discovery): reading a built derivation's contents during eval is
    # import-from-derivation, which forces a build just to answer e.g. "is
    # qodo enabled?" and breaks cross-system eval (an aarch64-darwin
    # machine can't build an x86_64-linux derivation just to list it).
    # Contributors that don't know their skill names statically should
    # expose them via the producing package's `passthru` instead (see
    # `qodo-cli-skills`).
    skills = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Skills to expose via `programs.claude-code.skills`, keyed by skill
        name (renders to `''${configDir}/skills/<name>`). Other tool modules
        contribute entries here instead of setting
        `programs.claude-code.skills` directly.
      '';
    };

    hooks = mkAgentHooksOption ''
      Command hooks merged into `settings.json` on each activation. Not
      `programs.claude-code.settings.hooks`: that makes the whole file a
      read-only store link, while Claude Code, its plugin installs and any
      other tools all write to it at runtime.
    '';
  };

  config = mkIf cfg.enable {
    home.activation.claudeCodeHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.hm.generators.mkImpureConfigMerger (
        {
          inherit pkgs;
          format = "json";
          empty = "{}";
          mode = "600";
          path = "${config.programs.claude-code.configDir}/settings.json";
        }
        // mkAgentHooksMerge {
          inherit pkgs;
          inherit (cfg) hooks;
        }
      )
    );

    # `package = null`: manage config/skills files only, not the `claude`
    # binary itself (installed separately via the Homebrew cask -- see
    # modules/darwin/archetypes/work).
    #
    # The attrset form keeps each skill as its own independent `home.file`
    # entry rather than claiming the whole `skills/` directory, which would
    # conflict with home-manager's own `claude-code-home-manager` personal
    # plugin -- written to a path *inside* `skills/` -- the moment
    # `programs.claude-code.mcpServers`/`.lspServers` are ever set (see
    # `pluginFileEntries` in home-manager's claude-code module).
    programs.claude-code = {
      enable = true;
      package = null;
      skills = mkIf (cfg.skills != { }) cfg.skills;

      lspServers.nix = {
        command = "${pkgs.nixd}/bin/nixd";
        extensionToLanguage.".nix" = "nix";
      };
    };
  };
}
