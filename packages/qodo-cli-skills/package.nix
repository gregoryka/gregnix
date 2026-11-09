{
  stdenv,
  lib,
  fetchurl,
  jq,
  qodo-cli,
  ...
}:
let
  # Hardcoded rather than read from the build output, which would be
  # import-from-derivation (and break cross-system eval). The build fails
  # if this drifts from the bundle.
  skillNames = [
    "qodo-codebase-wisdom"
    "qodo-get-rules"
    "qodo-manage-standards"
    "qodo-review"
    "qodo-review-notes"
    "qodo-review-resolver"
    "qodo-setup"
  ];

  # `skills.releaseTag` in https://get.qodo.ai/version.json.
  version = "2.1.11";
in
# Decodes the same checksummed bundle `qodo skills install` downloads and
# writes verbatim, since that command requires `qodo login`.
# `out` is unused but required by stdenv's multiple-outputs hook.
stdenv.mkDerivation {
  pname = "qodo-cli-skills";
  inherit version;

  src = fetchurl {
    url = "https://get.qodo.ai/skills/releases/v${version}/qodo-cli-managed-bundle.json";
    hash = "sha256-EN6+vcGSHHsVrdzhUt03lDwEeBy9F7qTPOveGobk2+4=";
  };

  outputs = [
    "out"
    "claudeCode"
    "devin"
  ];

  expectedSkillNames = lib.concatStringsSep " " skillNames;
  cliVersion = qodo-cli.version;

  dontUnpack = true;
  nativeBuildInputs = [ jq ];

  buildPhase = ''
    runHook preBuild

    minCli="$(jq -r .minimumCliVersion "$src")"
    if ! printf '%s\n%s\n' "$minCli" "$cliVersion" | sort -V -C; then
      echo "qodo-cli-skills: bundle requires qodo-cli >= $minCli, have $cliVersion" >&2
      exit 1
    fi

    actual="$(jq -r '.skills | keys[]' "$src" | sort)"
    expected="$(printf '%s\n' $expectedSkillNames | sort)"
    if [ "$actual" != "$expected" ]; then
      echo "qodo-cli-skills: bundled skill names no longer match the hardcoded" >&2
      echo "list in package.nix -- update \`skillNames\` there to match:" >&2
      echo "  expected: $expected" >&2
      echo "  actual:   $actual" >&2
      exit 1
    fi

    mkdir skills
    jq -r '.skills | to_entries[] | .key as $skill | .value.files[]
      | [$skill, .path, .sha256, .encoding, .content] | @tsv' "$src" |
      while IFS=$'\t' read -r skill path sha encoding content; do
        case "/$path/" in
          *//* | */./* | */../*)
            echo "qodo-cli-skills: unsafe path $skill/$path" >&2
            exit 1
            ;;
        esac
        [ "$encoding" = base64 ] || { echo "qodo-cli-skills: unknown encoding $encoding" >&2; exit 1; }
        dest="skills/$skill/$path"
        mkdir -p "$(dirname "$dest")"
        printf '%s' "$content" | base64 -d > "$dest"
        echo "$sha  $dest" | sha256sum -c --quiet
      done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    touch "$out"
    cp -r skills "$claudeCode"
    cp -r skills "$devin"
    runHook postInstall
  '';

  passthru = { inherit skillNames; };

  meta = {
    description = "Qodo's agent skills, from the pinned CLI-managed skills bundle (one output per supported coding agent)";
  };
}
