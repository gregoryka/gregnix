{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.keepingyouawake;
in
{
  options.gregnix.programs.graphical.apps.keepingyouawake = {
    enable = mkEnableOption "KeepingYouAwake (prevents the system from sleeping)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "keepingyouawake" ];
  };
}
