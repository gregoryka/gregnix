{
  lib,
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.raycast.mkExtension pkgs {
  name = "brew";
  version = "0-unstable-2026-08-13";
  rev = "a6faca32d6e243f35c3b3eeb881139aaad105d90";
  hash = "sha256-+eWWML/OiijyHJAKFkpGORGJU3TErzLOigOnRKkhwvw=";
  packageJson = ./package.json;
  packageLock = ./package-lock.json;
  # assets/askpass.sh is checked into upstream git as non-executable, and the
  # extension lazily `chmod +x`es it on first run. That fails here since the
  # extension is symlinked read-only from the Nix store into
  # `~/.local/share/vicinae/extensions`, so make it executable at build time.
  postInstall = ''
    chmod +x "$out/assets/askpass.sh"
  '';
  meta = {
    description = "Raycast Homebrew extension for Vicinae";
    platforms = lib.platforms.darwin;
  };
}
