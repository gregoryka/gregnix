{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "1password-cli"
            "qodo-cli"
            "sonarqube-cli"
          ];
      };

      packageFunctions = lib.filesystem.packagesFromDirectoryRecursive {
        directory = ../packages;
        callPackage = file: _args: import file;
      };

      builtPackages = lib.fix (
        self:
        lib.mapAttrs (
          _name: packageFn: pkgs.callPackage packageFn (self // { inherit inputs; })
        ) packageFunctions
      );

      availablePackages = lib.filterAttrs (
        _name: package: lib.meta.availableOn pkgs.stdenv.hostPlatform package
      ) builtPackages;
    in
    {
      packages = availablePackages;
    };
}
