{
  lib,
  makeSetupHook,
  sequoia-sqv,
  ...
}:
# Add to nativeBuildInputs with pgpSignature, pgpKey and pgpFingerprint set.
makeSetupHook {
  name = "pgp-check-hook";
  propagatedBuildInputs = [ sequoia-sqv ];
  # Set as `inherit (pgp-check-hook.keys.<name>) pgpKey pgpFingerprint;`.
  passthru.keys = {
    # SonarSource S.A.'s release key. Matches both the key pinned in
    # sonarqube-cli's src/core/host/install/signatures.ts and keys.openpgp.org.
    sonarsource = {
      pgpKey = ./keys/sonarsource.asc;
      pgpFingerprint = "679F1EE92B19609DE816FDE81DB198F93525EC1A";
    };
  };
  meta = {
    description = "Setup hook that verifies a download against a pinned PGP key";
    platforms = lib.platforms.all;
  };
} ./pgp-check.sh
