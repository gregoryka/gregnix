{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.utm;
in
{
  options.gregnix.programs.graphical.apps.utm = {
    enable = mkEnableOption "UTM (virtual machines UI using QEMU)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "utm" ];
  };
}
