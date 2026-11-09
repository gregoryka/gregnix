{
  lib,
  stdenvNoCC,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  installShellFiles,
  ...
}:
# On Darwin it installs the upstream release binary untouched
# rather than building from source: that binary is Developer ID signed,
# notarized and hardened-runtime, so jk's Keychain item stays bound to a
# stable designated requirement across updates (see ARCHITECTURE.md's
# executable-bound keychain storage). Elsewhere it builds from source.
let
  version = "0.0.42";

  darwinReleaseHashes = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-0ELY75Hw493s59ksC3nDDFvJhwmiSNpYf6Arb+V/y+c=";
    };
    x86_64-darwin = {
      arch = "x86_64";
      hash = "sha256-2ri3e6qiUOxfij8zyqB2LUYuyzql2lNilBVQuRXuN58=";
    };
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
      release = darwinReleaseHashes.${stdenvNoCC.hostPlatform.system};
    in
    stdenvNoCC.mkDerivation {
      pname = "jk";
      inherit version;

      src = fetchurl {
        url = "https://github.com/avivsinai/jenkins-cli/releases/download/v${version}/jk_${version}_darwin_${release.arch}.tar.gz";
        inherit (release) hash;
      };

      sourceRoot = ".";

      nativeBuildInputs = [ installShellFiles ];

      # Stripping or patching the Mach-O would invalidate the vendor
      # signature.
      dontFixup = true;

      installPhase = ''
        runHook preInstall
        install -Dm0755 jk "$out/bin/jk"
        ${installCompletions}
        ${installSkill}
        runHook postInstall
      '';

      meta = meta // {
        platforms = builtins.attrNames darwinReleaseHashes;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    };

  fromSource = buildGoModule {
    pname = "jk";
    inherit version;

    src = fetchFromGitHub {
      owner = "avivsinai";
      repo = "jenkins-cli";
      tag = "v${version}";
      hash = "sha256-ddlDrG0m0TyGMkriJcnVznXLKFE3aUXB1mZYbQQYqPE=";
    };

    vendorHash = "sha256-fndhR1fwOalFTVxA9KI6plNsfsiyRh9Nb8OI0qcHoik=";

    subPackages = [ "cmd/jk" ];

    nativeBuildInputs = [ installShellFiles ];

    ldflags = [
      "-s"
      "-X github.com/avivsinai/jenkins-cli/internal/build.versionFromLdflags=${version}"
    ];

    postInstall =
      lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) installCompletions
      + installSkill;

    inherit meta;
  };
in
if stdenvNoCC.hostPlatform.isDarwin then darwinRelease else fromSource
