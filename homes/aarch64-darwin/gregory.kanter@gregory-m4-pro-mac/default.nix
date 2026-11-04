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
  inherit (config.gregnix.programs.terminal.tools.ssh) secretiveSocket;

  inherit (pkgs.gregnix.git-ssh-keygen-secretive) secretiveForwardedSocket;
in
{
  gregnix = {
    archetypes.work.enable = true;

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
          tokenSopsFile = lib.getFile "secrets/work/gregory-m4-pro-mac/gh.yaml";
          enterpriseTokenSopsFile = lib.getFile "secrets/work/gregory-m4-pro-mac/gh.yaml";
        };
        git.enable = true;
        lazygit.enable = true;
        nh.enable = true;
        podman.enable = true;
        qodo.tokenSopsFile = lib.getFile "secrets/work/gregory-m4-pro-mac/qodo.yaml";
        ripgrep.enable = true;
        ssh = {
          enable = true;

          hosts = {
            "dev-vm" = {
              hostName = config.sops.placeholder.dev_vm_ip;
              user = "user";
              identityAgent = secretiveSocket;
              publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJFdl9FOAgLXOpRupIEvaowKVQjG4ScYK7v2j+lW19RILGHamIhnsNQP0CRhWG5lKrcYV4KjQ4ezjQ9a+rcnTok=";
              remoteForwards = [
                {
                  local = secretiveSocket;
                  remote = secretiveForwardedSocket;
                }
              ];
              hostKeys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDnMt0VZYFyjEgXGpErGwT0VSJ4wZ90tbmW9IVaUxKQ"
                "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJ+RpOd+liw8YFTykUvsu2dw8/jcFQjzzaPa2UfqXcu2Jl5J1UiUCQJefDjbXMJYje6m8yCJTTYtmH/kndhmab0="
                "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5QKChzryXeGNMtNO8G7BS3DqJnHiRVu61X9tpEsYYrxRu+nRJSrlUak/vzD1DGSACkO5xLCvo19robrIDApFEw/ADFRxNTGTNXLZVH1AIw5uaoA7koa96SalE836nwxB/UeNSoFUwUxam4KeQuuIu/nhgaKfwGxxaiGBx+xK9aiwLKnLPf805A+efj9QuShQJAGql6/F7mvJBlT6FT0lCnm36qbTxDhpsK5zSaCIk7nIvz2Qo8kuyqesXKZTth9Hu571IjZbPV3DkK/7hwhWCdzeh1QQZIoyxuUfR0S9YpK5lSp88EwKGfbR14EzuMXc8kreCv8Z44tOh+Rd79rgop+rBxKZc0B1iKrpmnaL62qTWyM12m3GQDn3tWyxZw9dfke+31DJIgaug+VYmYusZJm/aIVis0+PWhXb2I+EFO6h61fhEbi18nEkX3Bmkh8gXk9lQaK4hBi5VTRl6v6EPLQwdF4paA1voNBWAIMNRO3BJXmPt4TOjNhr/sviw2a8="
              ];
            };

            "github.com" = {
              user = "git";
              identityAgent = secretiveSocket;
              publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIFn4LwHejbKrC95+ysTZK3UZ4gSlHsC/cjTY6boWCjlfAc1jcuoW6UX36QpzATPzMqlq0aqjhHSCVcB8Jt/EcA=";
              identitiesOnly = true;
            };

            "ghe" = {
              user = "git";
              identityAgent = secretiveSocket;
              publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMJ6D2lXvPwSyT4KVjX/S0N2rxYV6K7Ik1uxbVATiBlfdimu//Kg+BxE94pQC/Q7Gx34E9HDKtCshPjjwLO/Xb4=";
              identitiesOnly = true;
            };
          };
        };
        starship.enable = true;
        vim.enable = true;
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
