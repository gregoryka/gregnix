{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.middleclick;
in
{
  options.gregnix.programs.graphical.apps.middleclick = {
    enable = mkEnableOption "MiddleClick (extends trackpad functionality)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "middleclick" ];
  };
}
