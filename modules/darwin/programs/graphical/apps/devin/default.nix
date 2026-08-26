{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.devin;
in
{
  options.gregnix.programs.graphical.apps.devin = {
    enable = mkEnableOption "Devin (GUI app + CLI)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [
      "devin-desktop"
      "devin-cli"
    ];
  };
}
