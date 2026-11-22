{ inputs, ... }:
{
  imports = [ inputs.nix-unit.modules.flake.default ];

  perSystem = {
    nix-unit = {
      # `checks.<system>.nix-unit` evaluates root `self#tests` in the build
      # sandbox. Pass locked root inputs explicitly so the check stays offline.
      inputs = {
        inherit (inputs)
          flake-parts
          git-hooks-nix
          home-manager
          nix-darwin
          nix-unit
          nixpkgs
          nur
          sops-nix
          treefmt-nix
          ;
      };
    };
  };
}
