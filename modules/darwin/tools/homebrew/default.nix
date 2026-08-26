{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.gregnix.tools.homebrew;
in
{
  options.gregnix.tools.homebrew = {
    enable = lib.mkEnableOption "homebrew";
  };

  config = mkIf cfg.enable {
    # https://docs.brew.sh/Manpage#environment
    environment.variables = {
      HOMEBREW_BAT = "1";
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_INSECURE_REDIRECT = "1";
    };
    environment.systemPath = [ "${config.homebrew.prefix}/bin" ];

    homebrew = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;

      global = {
        brewfile = true;
        autoUpdate = true;
      };

      onActivation = {
        autoUpdate = true;
        cleanup = "none";
        upgrade = false;
      };
    };
  };
}
