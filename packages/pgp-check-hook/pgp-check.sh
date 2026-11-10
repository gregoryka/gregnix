# shellcheck shell=bash
# shellcheck disable=SC2154 # pgp* are set by the derivation using the hook
# Fails the build unless $pgpSignature is a valid detached signature of
# ${pgpData:-$src} made by the key with primary fingerprint $pgpFingerprint,
# found in the armored key file $pgpKey. Runs before the install phase, so
# nothing is installed (or patched) from an unverified download.

pgpCheck() {
  local var
  for var in pgpSignature pgpKey pgpFingerprint; do
    if [[ -z ${!var-} ]]; then
      echo "pgpCheckHook: $var is not set" >&2
      return 1
    fi
  done
  local data=${pgpData:-$src} signer
  # sqv prints the primary fingerprint of each key with a valid signature.
  signer=$(sqv --keyring "$pgpKey" --signature-file "$pgpSignature" "$data") || signer=
  if [[ $signer != "$pgpFingerprint" ]]; then
    echo "pgpCheckHook: $data has no valid signature from $pgpFingerprint" >&2
    return 1
  fi
  echo "pgpCheckHook: verified $data against $pgpFingerprint"
}

preInstallHooks+=(pgpCheck)
