{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.gregnix.programs.terminal.tools.lazygit;
in
{
  options.gregnix.programs.terminal.tools.lazygit = {
    enable = lib.mkEnableOption "lazygit";
  };

  config = mkIf cfg.enable {
    programs.lazygit = {
      enable = true;

      settings = {
        gui = {
          theme = {
            authorColors = {
              "${config.gregnix.user.fullName}" = "#c6a0f6";
              "dependabot[bot]" = "#eed49f";
            };
            branchColorPatterns = {
              "^main$" = "#ed8796";
              "^master$" = "#ed8796";
              "^dev" = "#8bd5ca";
            };
          };
          nerdFontsVersion = "3";
          showListFooter = false;
          showRandomTip = false;
          expandFocusedSidePanel = true;
          shortTimeFormat = "15:04";
        };

        git = {
          overrideGpg = true;
          mainBranches = [
            "main"
            "master"
            "develop"
          ];
        };

        customCommands = import ./custom-commands.nix;
      };
    };
  };
}
