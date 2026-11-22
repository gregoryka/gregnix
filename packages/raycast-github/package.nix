{ pkgs, inputs, ... }:
inputs.self.lib.raycast.mkExtension pkgs {
  name = "github";
  version = "0-unstable-2026-08-13";
  rev = "a6faca32d6e243f35c3b3eeb881139aaad105d90";
  hash = "sha256-uMs2tU3vqy71eQSBELazffBzSrqcQJ0jI/HDiP1tqB0=";
  packageJson = ./package.json;
  packageLock = ./package-lock.json;
  meta.description = "Raycast GitHub extension for Vicinae";
}
