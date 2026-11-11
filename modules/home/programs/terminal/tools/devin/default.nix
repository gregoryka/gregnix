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

  cfg = config.gregnix.programs.terminal.tools.devin;
in
{
  options.gregnix.programs.terminal.tools.devin = {
    enable = mkEnableOption "Devin CLI config management (skills, etc.)";

    # Mirrors the claude-code tool module's `skills`: an `attrsOf` merges
    # natively across module definitions, so other tool modules (e.g.
    # qodo) can contribute entries here instead of writing under
    # `~/.config/devin/skills` themselves. Name -> directory (not
    # discovered via `builtins.readDir` on a built derivation) so
    # referencing this option never forces a build during eval -- see the
    # claude-code module's `skills` option for why that matters.
    skills = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Skills to place under `~/.config/devin/skills`, keyed by skill
        name. Other tool modules contribute here instead of writing into
        that directory directly.
      '';
    };

    hooks = mkAgentHooksOption ''
      Command hooks merged into `~/.config/devin/config.json` on each
      activation (Devin ignores a global `hooks.v1.json`). The file stays
      writable: Devin itself and other tools write to it at runtime.
    '';
  };

  config = mkIf cfg.enable {
    home.activation.devinHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.hm.generators.mkImpureConfigMerger (
        {
          inherit pkgs;
          format = "json";
          empty = "{}";
          mode = "600";
          path = "${config.home.homeDirectory}/.config/devin/config.json";
        }
        // mkAgentHooksMerge {
          inherit pkgs;
          inherit (cfg) hooks;
        }
      )
    );

    home.file = lib.mapAttrs' (
      name: dir:
      lib.nameValuePair ".config/devin/skills/${name}" {
        source = dir;
        recursive = true;
      }
    ) cfg.skills;
  };
}
