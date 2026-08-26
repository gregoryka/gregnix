{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.karabiner-elements;
in
{
  options.gregnix.programs.graphical.apps.karabiner-elements = {
    enable = mkEnableOption "Karabiner-Elements (keyboard customiser)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "karabiner-elements" ];
  };
}
