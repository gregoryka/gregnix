{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps._1password;
in
{
  options.gregnix.programs.graphical.apps._1password = {
    enable = mkEnableOption "1Password (GUI app + CLI)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [
      "1password"
      "1password-cli"
    ];
  };
}
