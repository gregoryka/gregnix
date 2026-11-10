# shellcheck shell=bash
# shellcheck disable=SC2154 # githubAttestation* are set by the derivation using the hook
# Fails the build unless ${githubAttestationData:-$src} is covered by both
# attestations in $githubAttestations (from passthru.fetchAttestations):
#  - SLSA build provenance, signed through the Sigstore public-good instance
#    and Rekor-logged, from $githubAttestationWorkflow in
#    $githubAttestationRepo at $githubAttestationSourceRef, with both the
#    source and the workflow at $githubAttestationCommit, built on a
#    GitHub-hosted runner;
#  - GitHub's immutable-release attestation, listing it as an asset of
#    $githubAttestationTag and recording that tag as $githubAttestationCommit.
# Verification is offline, against the vendored trusted root. Runs before
# the install phase, so nothing is installed from an unverified download.

githubAttestationCheck() {
  local var
  for var in githubAttestations githubAttestationRepo githubAttestationWorkflow \
    githubAttestationSourceRef githubAttestationTag githubAttestationCommit; do
    if [[ -z ${!var-} ]]; then
      echo "githubAttestationCheckHook: $var is not set" >&2
      return 1
    fi
  done
  local data=${githubAttestationData:-$src} work
  work=$(mktemp -d)

  jq -c '.provenance[]' "$githubAttestations" >"$work/provenance.jsonl"
  if ! HOME=$work GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 gh attestation verify "$data" \
    --bundle "$work/provenance.jsonl" \
    --custom-trusted-root @trustedRoot@ \
    --repo "$githubAttestationRepo" \
    --signer-workflow "$githubAttestationRepo/$githubAttestationWorkflow" \
    --signer-digest "$githubAttestationCommit" \
    --source-ref "$githubAttestationSourceRef" \
    --source-digest "$githubAttestationCommit" \
    --deny-self-hosted-runners >"$work/gh.log" 2>&1; then
    cat "$work/gh.log" >&2
    echo "githubAttestationCheckHook: $data has no matching build provenance" >&2
    return 1
  fi

  # GitHub signs release attestations with its own Sigstore instance, which
  # has no transparency or certificate-transparency log: trust rests on its
  # CA and timestamp authority alone, as in `gh release verify`.
  jq -c '.release' "$githubAttestations" >"$work/release.json"
  jq -c 'select(any(.certificateAuthorities[]; .uri == "fulcio.githubapp.com"))' \
    @trustedRoot@ >"$work/github-root.json"
  if ! HOME=$work cosign verify-blob-attestation "$data" \
    --bundle "$work/release.json" \
    --trusted-root "$work/github-root.json" \
    --type https://in-toto.io/attestation/release/v0.2 \
    --certificate-identity https://dotcom.releases.github.com \
    --certificate-oidc-issuer-regexp '.*' \
    --use-signed-timestamps --insecure-ignore-tlog --insecure-ignore-sct \
    >"$work/cosign.log" 2>&1; then
    cat "$work/cosign.log" >&2
    echo "githubAttestationCheckHook: $data is not an asset of a GitHub release" >&2
    return 1
  fi
  # The statement cosign just verified.
  if ! jq -e --arg repo "$githubAttestationRepo" --arg tag "$githubAttestationTag" \
    --arg commit "$githubAttestationCommit" '
      .dsseEnvelope.payload | @base64d | fromjson
      | .predicate.repository == $repo and .predicate.tag == $tag
        and any(.subject[]; .uri == "pkg:github/\($repo)@\($tag)" and .digest.sha1 == $commit)
    ' "$work/release.json" >/dev/null; then
    echo "githubAttestationCheckHook: release attestation is not for $githubAttestationRepo $githubAttestationTag at $githubAttestationCommit" >&2
    return 1
  fi

  rm -rf "$work"
  echo "githubAttestationCheckHook: verified $data as $githubAttestationRepo $githubAttestationTag ($githubAttestationCommit)"
}

preInstallHooks+=(githubAttestationCheck)
