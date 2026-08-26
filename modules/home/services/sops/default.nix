{
  config,
  lib,
  pkgs,
  inputs,

  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.gregnix) mkOpt;

  cfg = config.gregnix.services.sops;

  agePlugins =
    lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      pkgs.gregnix.age-plugin-tagpq
      # Decryption identity is Secure Enclave-backed (age-plugin-se, hybrid
      # P256 + ML-KEM-768 for post-quantum security). Generate one with:
      #   age-plugin-se keygen --pq --access-control none -o ~/.config/sops/age/keys.txt
      inputs.nur.legacyPackages.${pkgs.stdenv.hostPlatform.system}.repos.josh.age-plugin-se
    ]
    ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
      pkgs.gregnix.age-plugin-pq
    ];
in
{
  options.gregnix.services.sops = {
    enable = lib.mkEnableOption "sops";
    defaultSopsFile = mkOpt (lib.types.nullOr lib.types.path) null "Default sops file.";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.rage
      pkgs.sops
    ]
    # Also needed on the interactive PATH for using the sops/age CLI
    # directly (e.g. `sops edit`), not just by the sops-nix launchd agent.
    ++ agePlugins;

    sops = {
      inherit (cfg) defaultSopsFile;
      defaultSopsFormat = "yaml";

      age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      # Also adds these to PATH for the Darwin sops-nix launchd agent (which
      # otherwise only sees /usr/bin:/bin:/usr/sbin:/sbin, meaning it can't
      # exec the plugin to unwrap SE-backed identities). See
      # https://github.com/Mic92/sops-nix/issues/890.
      age.plugins = agePlugins;
    };

    programs.zsh.initContent = mkIf config.programs.zsh.enable ''
      eval "$(sops completion zsh)"
    '';
  };
}
