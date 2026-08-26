{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.graphical.apps.secretive;
in
{
  options.gregnix.programs.graphical.apps.secretive = {
    enable = mkEnableOption "Secretive (SSH keys backed by the Secure Enclave)";
  };

  config = mkIf cfg.enable {
    gregnix.tools.homebrew.enable = true;

    homebrew.casks = [ "secretive" ];
  };
}
