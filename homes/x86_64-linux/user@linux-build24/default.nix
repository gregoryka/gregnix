{ lib, ... }:
{
  gregnix = {
    archetypes.work.enable = true;

    user = {
      enable = true;
      name = "user";
    };

    programs.terminal = {
      shell.zsh.enable = true;
      tools = {
        atuin.enable = true;
        bat.enable = true;
        direnv.enable = true;
        eza.enable = true;
        fd.enable = true;
        fzf.enable = true;
        gh = {
          tokenSopsFile = lib.getFile "secrets/work/linux-build24/gh.yaml";
          enterpriseTokenSopsFile = lib.getFile "secrets/work/linux-build24/gh.yaml";
        };
        git.enable = true;
        lazygit.enable = true;
        nh.enable = true;
        ripgrep.enable = true;
        ssh = {
          enable = true;
          authorizedKeys = [
            # Secretive-backed key on the Mac, allowed to log in as this user.
            "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJFdl9FOAgLXOpRupIEvaowKVQjG4ScYK7v2j+lW19RILGHamIhnsNQP0CRhWG5lKrcYV4KjQ4ezjQ9a+rcnTok="
            # 1Password stored ssh key, for backup access
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPP5CGim0pS4RQLjTrMC8OaI1aO5n7H8Ajuy/mf+F1VX"
          ];
        };
        starship.enable = true;
        terminfo.enable = true;
        yazi.enable = true;
        zellij.enable = true;
        zoxide.enable = true;

        jk.keyringPassphraseSopsFile = lib.getFile "secrets/work/linux-build24/jk.yaml";
        qodo.tokenSopsFile = lib.getFile "secrets/work/linux-build24/qodo.yaml";
        sonarqube.tokenSopsFile = lib.getFile "secrets/work/linux-build24/sonarqube.yaml";
      };
    };

    services.sops.enable = true;

    system.certs.enable = true;
    system.xdg.enable = true;
  };

  home.stateVersion = "26.05";
}
