{
  lib,
  makeSetupHook,
  fetchurl,
  cosign,
  gh,
  jq,
  ...
}:
# Add to nativeBuildInputs with githubAttestations (from fetchAttestations)
# and the githubAttestation* policy attributes the script documents set.
makeSetupHook {
  name = "github-attestation-check-hook";
  propagatedBuildInputs = [
    cosign
    gh
    jq
  ];
  substitutions = {
    # Sigstore public-good and GitHub trusted roots, from
    # `gh attestation trusted-root` (which verifies them through TUF).
    # Regenerate when a release is signed by keys this copy predates.
    trustedRoot = ./trusted_root.jsonl;
  };
  passthru = {
    # The build provenance and release attestations GitHub holds for an
    # artifact, given its hex sha256. The API response also carries
    # short-lived download URLs, so only the bundles are kept.
    fetchAttestations =
      {
        repo,
        sha256,
        hash,
      }:
      fetchurl {
        name = "github-attestations-${sha256}.json";
        url = "https://api.github.com/repos/${repo}/attestations/sha256:${sha256}";
        inherit hash;
        nativeBuildInputs = [ jq ];
        postFetch = ''
          jq -S '
            [.attestations[].bundle] as $bundles
            | def ofType($t): [$bundles[] | select(.dsseEnvelope.payload | @base64d | fromjson | .predicateType == $t)];
            {
              provenance: (ofType("https://slsa.dev/provenance/v1") | sort_by(.dsseEnvelope.signatures[0].sig)),
              release: (ofType("https://in-toto.io/attestation/release/v0.2") | if length == 1 then .[0] else error("expected one release attestation, got \(length)") end)
            }
          ' "$out" > "$TMPDIR/attestations.json"
          mv "$TMPDIR/attestations.json" "$out"
        '';
      };
  };
  meta = {
    description = "Setup hook that verifies GitHub build provenance and release attestations offline";
    platforms = lib.platforms.all;
  };
} ./github-attestation-check.sh
