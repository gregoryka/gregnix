{ pkgs, inputs, ... }:
inputs.self.lib.raycast.mkExtension pkgs {
  name = "1password";
  version = "0-unstable-2026-08-13";
  rev = "a6faca32d6e243f35c3b3eeb881139aaad105d90";
  hash = "sha256-NpAJi443OsEQwGKb/Tpkobn6pmjzwwYvTJjgvfMv/D8=";
  packageJson = ./package.json;
  packageLock = ./package-lock.json;
  # Upstream bug: `{vaults?.length && vaults.map(...)}` renders the
  # literal number `0` (not `false`) as a JSX child when the vault
  # list is empty. Real Raycast's DOM renderer tolerates a stray
  # "0" text node; vicinae's reconciler doesn't implement
  # `createTextInstance` for `List.Section` children at all and
  # crashes instead. Coerce to a real boolean so no text node is
  # ever produced.
  postPatch = ''
    substituteInPlace src/v8/components/Vaults.tsx \
      --replace-fail '{vaults?.length &&' '{!!vaults?.length &&'
  '';
  meta.description = "Raycast 1Password extension for Vicinae";
}
