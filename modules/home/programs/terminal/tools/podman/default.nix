{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.gregnix.programs.terminal.tools.podman;
in
{
  options.gregnix.programs.terminal.tools.podman = {
    enable = mkEnableOption "Podman (daemonless container engine)";
  };

  config = mkIf cfg.enable {
    # On Darwin this also declaratively creates/manages the
    # "podman-machine-default" VM and keeps it running via a launchd watchdog
    # agent. See home-manager's modules/services/podman/darwin.nix.
    #
    # useDefaultMachine hardcodes podman's defaults (2 GiB RAM), too little
    # for parallel clang builds, so the same machine is declared explicitly
    # instead. home-manager only applies these on `podman machine init`; an
    # existing machine keeps its size until `podman machine set` (run while
    # it's stopped) or it's recreated.
    #
    # Rosetta must be on in containers.conf (podman 6 defaults it off, and
    # `podman machine set` re-reads it), or x86_64 containers fall back to
    # qemu-user.
    services.podman = {
      enable = true;
      settings.containers.machine.rosetta = true;
      useDefaultMachine = false;
      machines."podman-machine-default" = {
        cpus = 8;
        memory = 16384;
      };
    };
  };
}
