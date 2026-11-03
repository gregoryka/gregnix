{ lib, ... }:
{
  imports = [ (lib.getFile "modules/common/nix/default.nix") ];
}
