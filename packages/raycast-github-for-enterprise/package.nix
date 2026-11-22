{ pkgs, inputs, ... }:
inputs.self.lib.raycast.mkExtension pkgs {
  name = "github-for-enterprise";
  version = "0-unstable-2026-08-13";
  rev = "a6faca32d6e243f35c3b3eeb881139aaad105d90";
  hash = "sha256-qSR2XJdvg9zxaqc3ZBJ6gGsxncFIhcWqiaDZfZzgjoI=";
  packageJson = ./package.json;
  packageLock = ./package-lock.json;
  meta.description = "Raycast GitHub Enterprise extension for Vicinae";
}
