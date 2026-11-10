{
  lib,
  stdenvNoCC,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  installShellFiles,
  inputs,
  github-attestation-check-hook,
  ...
}:
# On Darwin it installs the upstream release binary untouched
# rather than building from source: that binary is Developer ID signed,
# notarized and hardened-runtime, so jk's Keychain item stays bound to a
# stable designated requirement across updates (see ARCHITECTURE.md's
# executable-bound keychain storage). Elsewhere it builds from source.
#
# Both builds check GitHub's attestations for the release: the Darwin one
# for the tarball it installs, the source one for the release's
# checksums.txt, which binds `commit` (built from source) to the tag.
let
  version = "0.0.45";
  repo = "avivsinai/jenkins-cli";
  # What tag v${version} points at, per its release attestation.
  commit = "4fd9cbf69fe2d63fb3cf0778a39f6ccf5d70c996";

  releaseAssets = {
    aarch64-darwin = {
      file = "jk_${version}_darwin_arm64.tar.gz";
      hash = "sha256-+i5QIEJYV45d65C1liIhtGY5iKMXSOgViGP5Im0fqSc=";
    };
    x86_64-darwin = {
      file = "jk_${version}_darwin_x86_64.tar.gz";
      hash = "sha256-1j/KfsFmNd/iE4nvZawSorZGAbXTZq/1cSonDuzPGuE=";
    };
    checksums = {
      file = "checksums.txt";
      # Hex, as the attestation lookup below needs it.
      sha256 = "b447b1e233a0b0452506c23c7251644dc6b82fb46b862620cd5e08703dc14f9d";
    };
  };

  fetchReleaseAsset =
    asset:
    fetchurl {
      url = "https://github.com/${repo}/releases/download/v${version}/${asset.file}";
      hash = asset.hash or "sha256:${asset.sha256}";
    };

  attestationPolicy = {
    # One build provenance statement covers every file of the release, as
    # does the release attestation, so any asset's lookup returns both.
    githubAttestations = github-attestation-check-hook.fetchAttestations {
      inherit repo;
      inherit (releaseAssets.checksums) sha256;
      hash = "sha256-OTWotd6XL4tLVNpltjGQfD+qGy/OPoj3VPeyCwmlBcc=";
    };
    githubAttestationRepo = repo;
    githubAttestationWorkflow = ".github/workflows/release.yml";
    githubAttestationSourceRef = "refs/heads/main";
    githubAttestationTag = "v${version}";
    githubAttestationCommit = commit;
  };

  installCompletions = ''
    installShellCompletion --cmd jk \
      --bash <($out/bin/jk completion bash) \
      --fish <($out/bin/jk completion fish) \
      --zsh <($out/bin/jk completion zsh)
  '';

  # Upstream's agent skill, shipped in both the release tarball and the
  # source tree.
  installSkill = ''
    mkdir -p "$out/share/jk/skills"
    cp -r skills/jk "$out/share/jk/skills/"
  '';

  meta = {
    description = "GitHub-style CLI for Jenkins";
    homepage = "https://github.com/avivsinai/jenkins-cli";
    license = lib.licenses.mit;
    mainProgram = "jk";
  };

  darwinRelease =
    let
      release = releaseAssets.${stdenvNoCC.hostPlatform.system};
    in
    stdenvNoCC.mkDerivation (
      {
        pname = "jk";
        inherit version;

        src = fetchReleaseAsset release;

        sourceRoot = ".";

        nativeBuildInputs = [
          installShellFiles
          github-attestation-check-hook
        ];

        # Stripping or patching the Mach-O would invalidate the vendor
        # signature.
        dontFixup = true;

        doInstallCheck = true;
        nativeInstallCheckInputs = [
          inputs.llm-agents.packages.${stdenvNoCC.hostPlatform.system}.codesignCheckHook
        ];
        codesignTeamId = "93ZUZ2PTM9";

        installPhase = ''
          runHook preInstall
          install -Dm0755 jk "$out/bin/jk"
          ${installCompletions}
          ${installSkill}
          runHook postInstall
        '';

        meta = meta // {
          platforms = [
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        };
      }
      // attestationPolicy
    );

  fromSource = buildGoModule (
    {
      pname = "jk";
      inherit version;

      src = fetchFromGitHub {
        owner = "avivsinai";
        repo = "jenkins-cli";
        rev = commit;
        hash = "sha256-mLggp8xrUGKj+UPvFI5q4P9XzWb40cpIFJQq43q39K8=";
      };

      vendorHash = "sha256-9Ba76thpaEQn0TMtpdacH0VGfnFNZmMIUz+wWbcvvAU=";

      subPackages = [ "cmd/jk" ];

      nativeBuildInputs = [
        installShellFiles
        github-attestation-check-hook
      ];

      githubAttestationData = fetchReleaseAsset releaseAssets.checksums;

      # The module fetch inherits nativeBuildInputs but not the policy, and
      # vendorHash already pins it.
      overrideModAttrs = old: {
        nativeBuildInputs = lib.remove github-attestation-check-hook old.nativeBuildInputs;
      };

      ldflags = [
        "-s"
        "-X github.com/avivsinai/jenkins-cli/internal/build.versionFromLdflags=${version}"
      ];

      postInstall =
        lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) installCompletions
        + installSkill;

      inherit meta;
    }
    // attestationPolicy
  );
in
if stdenvNoCC.hostPlatform.isDarwin then darwinRelease else fromSource
