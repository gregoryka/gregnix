{
  lib,
  stdenv,
  fetchurl,
  pkgs,
  inputs,
  pgp-check-hook,
  ...
}:
# nixpkgs' sonarqube-cli, plus checks of the vendor binary against
# SonarSource's detached PGP signature and, on macOS, its Developer ID
# signature. Referenced through `pkgs` because `sonarqube-cli` here resolves
# to this package itself.
let
  inherit (pkgs) sonarqube-cli;

  # Signatures for the nixpkgs version below; bump them together.
  version = "1.11.0.16877";
  signatureHashes = {
    x86_64-linux = "sha256-30h1h+h/u9xz4MphniGiJUM2qMwPcngBcehekoUfjgA=";
    aarch64-linux = "sha256-PMmJJCRQHqIphu4TfrK6O1L7XDQhCNuxzra6o47AqEQ=";
    aarch64-darwin = "sha256-IQA7wGSIsiRFMwItmGpkAsinPbW6XLtZBBfWFOo5qo0=";
  };
in
assert lib.assertMsg (sonarqube-cli.version == version)
  "gregnix sonarqube-cli: nixpkgs now ships ${sonarqube-cli.version}; update the pinned signature hashes for it (pinned: ${version})";
sonarqube-cli.overrideAttrs (old: {
  pgpSignature = fetchurl {
    url = "${old.src.url}.asc";
    hash = signatureHashes.${stdenv.hostPlatform.system};
  };
  inherit (pgp-check-hook.keys.sonarsource) pgpKey pgpFingerprint;
  codesignTeamId = "4ZTCVDL4KL";

  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pgp-check-hook ];
  nativeInstallCheckInputs =
    old.nativeInstallCheckInputs or [ ]
    ++
      lib.optional stdenv.hostPlatform.isDarwin
        inputs.llm-agents.packages.${stdenv.hostPlatform.system}.codesignCheckHook;
})
