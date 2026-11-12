{
  config,
  lib,

  ...
}:
let
  cfg = config.gregnix.archetypes.personal;
in
{
  options.gregnix.archetypes.personal = {
    enable = lib.mkEnableOption "the personal archetype";
  };

  config = lib.mkIf cfg.enable {
    gregnix.programs.terminal.tools.git.identities.github-personal = {
      remotes = [ "github.com" ];
      email = "17238063+gregoryka@users.noreply.github.com";
    };
  };
}
