{ pkgs, inputs, ... }:
inputs.self.lib.raycast.mkExtension pkgs {
  name = "jira";
  version = "0-unstable-2026-08-13";
  rev = "a6faca32d6e243f35c3b3eeb881139aaad105d90";
  hash = "sha256-3eMdi6sdkhOXKjFpBjnjFGKPFYI/Y9/WXb66+PWDSSs=";
  packageJson = ./package.json;
  packageLock = ./package-lock.json;
  meta.description = "Raycast Jira extension for Vicinae";
}
