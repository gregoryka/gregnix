{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.gregnix.programs.terminal.tools.vim;
in
{
  options.gregnix.programs.terminal.tools.vim = {
    enable = lib.mkEnableOption "vim";
  };

  config = mkIf cfg.enable {
    programs.vim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
