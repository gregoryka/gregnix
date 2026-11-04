{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.gregnix.programs.terminal.tools.btop;
in
{
  options.gregnix.programs.terminal.tools.btop = {
    enable = lib.mkEnableOption "btop";
  };

  config = mkIf cfg.enable {
    programs.btop.enable = true;
  };
}
