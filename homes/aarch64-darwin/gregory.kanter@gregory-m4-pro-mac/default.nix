{
  config,
  lib,
  pkgs,
  osConfig ? { },

  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  inherit (config.gregnix.programs.graphical.apps.vicinae) mkRaycastExt;
in
{
  gregnix = {
    archetypes.work.enable = true;
    archetypes.devVmClient = {
      enable = true;
      identityPublicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJFdl9FOAgLXOpRupIEvaowKVQjG4ScYK7v2j+lW19RILGHamIhnsNQP0CRhWG5lKrcYV4KjQ4ezjQ9a+rcnTok=";
      vms."dev-vm" = {
        host = config.sops.placeholder.dev_vm_ip;
        hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDnMt0VZYFyjEgXGpErGwT0VSJ4wZ90tbmW9IVaUxKQ";
      };
    };

    user = {
      enable = true;
      name = "gregory.kanter";
    };

    programs.terminal = {
      shell.zsh.enable = true;
      emulators.kitty.enable = true;
      emulators.ghostty.enable = true;
      tools = {
        atuin.enable = true;
        bat.enable = true;
        direnv.enable = true;
        eza.enable = true;
        fd.enable = true;
        fzf.enable = true;
        gh = {
          tokenRef = "op://Employee/global-github-cli-pat/credential";
          enterpriseTokenRef = "op://Employee/global-ghe-cli-pat/credential";
        };
        git.enable = true;
        lazygit.enable = true;
        nh.enable = true;
        podman.enable = true;
        ripgrep.enable = true;
        ssh.enable = true;
        starship.enable = true;
        yazi.enable = true;
        zellij.enable = true;
        zoxide.enable = true;
      };
    };

    services.sops.enable = true;

    system.xdg.enable = true;

    programs.graphical.apps.vicinae = {
      settings = {
        telemetry.system_info = false;

        providers."@thomaslombart/jira".preferences.siteUrl = "sentinelone.atlassian.net";
        providers."@khasbilegt/1password".preferences.version = "v8";
      };

      secretSettings.providers."@thomaslombart/jira".preferences.email = config.sops.placeholder.email;

      extensions = [
        (mkRaycastExt "github" "sha256-uMs2tU3vqy71eQSBELazffBzSrqcQJ0jI/HDiP1tqB0=")
        (mkRaycastExt "github-for-enterprise" "sha256-qSR2XJdvg9zxaqc3ZBJ6gGsxncFIhcWqiaDZfZzgjoI=")
        (mkRaycastExt "jenkins" "sha256-ShHVPqN9PIBD4RGRID3RZcry1k2ww6qx3tYnD04FNzk=")
        (mkRaycastExt "jira" "sha256-3eMdi6sdkhOXKjFpBjnjFGKPFYI/Y9/WXb66+PWDSSs=")
      ]
      ++ lib.optional isDarwin (mkRaycastExt "brew" "sha256-+eWWML/OiijyHJAKFkpGORGJU3TErzLOigOnRKkhwvw=")
      ++ lib.optional (osConfig.gregnix.programs.graphical.apps._1password.enable or false) (
        (mkRaycastExt "1password" "sha256-NpAJi443OsEQwGKb/Tpkobn6pmjzwwYvTJjgvfMv/D8=").overrideAttrs
          (old: {
            # Upstream bug: `{vaults?.length && vaults.map(...)}` renders the
            # literal number `0` (not `false`) as a JSX child when the vault
            # list is empty. Real Raycast's DOM renderer tolerates a stray
            # "0" text node; vicinae's reconciler doesn't implement
            # `createTextInstance` for `List.Section` children at all and
            # crashes instead. Coerce to a real boolean so no text node is
            # ever produced.
            postPatch = ''
              substituteInPlace src/v8/components/Vaults.tsx \
                --replace-fail '{vaults?.length &&' '{!!vaults?.length &&'
            ''
            + (old.postPatch or "");
          })
      );
    };
  };

  sops.secrets.dev_vm_ip.sopsFile = lib.getFile "secrets/work/gregory-m4-pro-mac/ssh.yaml";

  home.stateVersion = "26.05";
}
