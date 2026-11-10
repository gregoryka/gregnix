{
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib.gregnix) mkBoolOpt mkOpt;

  cfg = config.gregnix.nix;
  isLix = cfg.useLix || (lib.getName cfg.package) == "lix";
in
{
  options.gregnix.nix = {
    enable = mkBoolOpt true "Whether to manage nix configuration.";
    useLix = mkBoolOpt false "Whether to use Lix as the nix implementation.";
    package =
      mkOpt lib.types.package pkgs.nixVersions.latest
        "Which nix package to use when not using Lix.";
  };

  config = lib.mkIf cfg.enable {
    nix = {
      package = if cfg.useLix then pkgs.lixPackageSets.stable.lix else cfg.package;

      settings = {
        allowed-users = [ config.gregnix.user.name ];
        trusted-users = [ config.gregnix.user.name ];
        experimental-features = [
          "nix-command"
          "flakes"
          (if isLix then "pipe-operator" else "pipe-operators")
        ];
        use-xdg-base-directories = true;

        substituters = [
          "https://nix-community.cachix.org"
          "https://nixpkgs-unfree.cachix.org"
          "https://cache.numtide.com"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };
    };
  };
}
