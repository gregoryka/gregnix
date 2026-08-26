{
  config,
  lib,

  ...
}:
let
  cfg = config.gregnix.archetypes.work;
in
{
  options.gregnix.archetypes.work = {
    enable = lib.mkEnableOption "the work archetype";
  };

  config = lib.mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [
      "claude"
      "claude-code@latest"
    ];
  };
}
