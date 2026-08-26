{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.podman-desktop;
in
{
  options.gregnix.programs.graphical.apps.podman-desktop = {
    enable = mkEnableOption "Podman Desktop (GUI for browsing/managing containers and images)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "podman-desktop" ];
  };
}
