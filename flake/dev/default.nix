{
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./checks.nix
    ./ci.nix
    ./devshells.nix
    ./tests.nix
    ./treefmt.nix
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = lib.mkDefault (
        import inputs.nixpkgs {
          inherit system;
          config = { };
        }
      );
    };
}
