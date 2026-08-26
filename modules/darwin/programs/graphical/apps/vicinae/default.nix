{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.vicinae;
in
{
  options.gregnix.programs.graphical.apps.vicinae = {
    enable = mkEnableOption "Vicinae (Raycast-compatible launcher, installed via Homebrew)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;
    homebrew.casks = [ "vicinae" ];
  };
}
