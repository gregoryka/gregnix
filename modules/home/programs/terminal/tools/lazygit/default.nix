{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib) mkIf escapeShellArg types;
  inherit (lib.gregnix) mkOpt;

  cfg = config.gregnix.programs.terminal.tools.lazygit;

  hasEnterpriseHosts = cfg.githubEnterpriseHosts != [ ];

  # The store file home-manager links into lazygit's config dir (only
  # `$XDG_CONFIG_HOME/lazygit` with `xdg.enable` on Darwin, so evaluation
  # fails loudly rather than pointing at the wrong file without it).
  baseConfigFile = config.home.file."${config.xdg.configHome}/lazygit/config.yml".source;
  servicesFile = escapeShellArg config.sops.templates."lazygit-services".path;

  # Lazygit errors out on any `LG_CONFIG_FILE` entry that's missing, so the
  # sops-rendered file is only merged in (on top of the base one) once it
  # has actually been rendered.
  #
  # No token injection needed: with `gh` on PATH, lazygit takes its pull
  # request token from `gh auth token --hostname <host>` (only reading
  # `GH_TOKEN`/`GH_ENTERPRISE_TOKEN` itself without one), and the
  # `gh` module's wrapper already injects those from sops.
  lazygitWithServices = pkgs.writeShellScriptBin "lazygit" ''
    LG_CONFIG_FILE=${baseConfigFile}
    if [[ -f ${servicesFile} ]]; then
      LG_CONFIG_FILE+=,${servicesFile}
    fi
    export LG_CONFIG_FILE
    exec ${lib.getExe pkgs.lazygit} "$@"
  '';
in
{
  options.gregnix.programs.terminal.tools.lazygit = {
    enable = lib.mkEnableOption "lazygit";

    githubEnterpriseHosts = mkOpt (types.listOf types.str) [ ] ''
      GitHub Enterprise hosts, as they appear in clone URLs (and serving
      the web UI/API too), e.g. `config.sops.placeholder.<name>` tokens.
      Each becomes a `services.<host> = "github:<host>"` entry, which also
      enables the branches panel's pull request icons for it. Rendered
      through a `sops.templates` entry, so a secret host never lands in
      the Nix store.
    '';
  };

  config = mkIf cfg.enable {
    # Rendered unconditionally (content may have no services): the hosts may
    # be `sops.placeholder.*` values, which only exist once
    # `sops.templates != {}`, and even checking the list for emptiness
    # type-checks them, so gating this template's key on it would be a
    # dependency cycle. JSON, as `content` must be a string; lazygit parses
    # it as YAML.
    sops.templates."lazygit-services".content = builtins.toJSON {
      services = lib.genAttrs cfg.githubEnterpriseHosts (host: "github:${host}");
    };

    programs.lazygit = {
      enable = true;
      package = if hasEnterpriseHosts then lazygitWithServices else pkgs.lazygit;

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
