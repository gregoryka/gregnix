{ lib, self, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      self',
      system,
      ...
    }:
    let
      # Only packages that declare a licence: one without `meta.license` may
      # wrap something that can't be redistributed, such as qodo-cli-skills.
      isRedistributable =
        drv:
        let
          licenses = lib.toList (drv.meta.license or [ ]);
        in
        licenses != [ ] && lib.all (license: license.redistributable or false) licenses;

      machineConfigs = lib.filter (cfg: cfg.pkgs.stdenv.hostPlatform.system == system) (
        lib.attrValues self.homeConfigurations ++ lib.attrValues self.darwinConfigurations
      );

      roots = lib.unique (
        lib.attrValues (lib.filterAttrs (_: isRedistributable) self'.packages)
        ++ [
          config.nix-unit.package
          pkgs.nix-index
        ]
        # Unfree but redistributable, so Hydra skips it; only
        # nix-community.cachix.org has it, and only for x86_64-linux.
        ++ map (cfg: cfg.pkgs._7zip-zstd-rar) machineConfigs
      );
    in
    {
      # What CI pushes to gregoryka.cachix.org from main: the runtime closure
      # of this link farm, minus what cache.nixos.org already has.
      legacyPackages.cachix-roots = pkgs.linkFarm "cachix-roots" (
        map (drv: {
          inherit (drv) name;
          path = drv;
        }) roots
      );
    };
}
