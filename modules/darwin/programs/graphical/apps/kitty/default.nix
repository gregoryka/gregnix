{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.kitty;
in
{
  options.gregnix.programs.graphical.apps.kitty = {
    enable = mkEnableOption "kitty (terminal emulator)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "kitty" ];
  };
}
