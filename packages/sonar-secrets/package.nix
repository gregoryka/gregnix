{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  coreutils,
  versionCheckHook,
  sonarqube-cli,
  inputs,
  pgp-check-hook,
  ...
}:
let
  version = "2.53.1.13823";

  releases = {
    aarch64-darwin = {
      platform = "macos-arm64";
      hash = "sha256-sTtkNlRjW12VU3JRl/672JugZfHlhrJ6lQ88h1Lwj8g=";
      signatureHash = "sha256-lemvIw9WFiZ5LD2uFngJSrssam2XFEJdPQvSy2HacQE=";
    };
    x86_64-linux = {
      platform = "linux-x86-64";
      hash = "sha256-T2fwKWyhnzWPrjvzLEMKHA5VslPoJXwq8C6Ioht15VI=";
      signatureHash = "sha256-uz05MJkrd0hx0jUh44u8bUUegw6am1BwokCvX8UUT9A=";
    };
  };

  release = releases.${stdenvNoCC.hostPlatform.system};
  url = "https://binaries.sonarsource.com/CommercialDistribution/sonar-secrets/sonar-secrets-${version}-${release.platform}.bin";
in
stdenvNoCC.mkDerivation {
  pname = "sonar-secrets";
  inherit version;

  src = fetchurl {
    inherit url;
    inherit (release) hash;
  };

  pgpSignature = fetchurl {
    url = "${url}.asc";
    hash = release.signatureHash;
  };
  inherit (pgp-check-hook.keys.sonarsource) pgpKey pgpFingerprint;
  codesignTeamId = "4ZTCVDL4KL";

  dontUnpack = true;
  nativeBuildInputs = [
    makeWrapper
    pgp-check-hook
  ]
  ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux zlib;

  # Patching or stripping the Mach-O would invalidate the vendor signature;
  # the Linux GraalVM image only gets its interpreter and rpath patched.
  dontFixup = stdenvNoCC.hostPlatform.isDarwin;
  dontStrip = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ]
  ++
    lib.optional stdenvNoCC.hostPlatform.isDarwin
      inputs.llm-agents.packages.${stdenvNoCC.hostPlatform.system}.codesignCheckHook;
  # The wrapper creates its cache directory under $HOME.
  versionCheckKeepEnvironment = [ "HOME" ];
  preVersionCheck = ''
    export HOME="$(mktemp -d)"
  '';

  installPhase = ''
    runHook preInstall

    # On Linux, bin/sonar is a wrapper script around bin/.sonar-wrapped.
    expected="$({ grep -rahom1 'SONAR_SECRETS_VERSION = "[0-9.]*' ${sonarqube-cli}/bin || true; } | head -n1 | cut -d'"' -f2)"
    if [ "$expected" != "$version" ]; then
      echo "sonar-secrets: sonarqube-cli ${sonarqube-cli.version} expects '$expected', packaged $version" >&2
      exit 1
    fi

    # The analyzer otherwise keeps its auth and custom-rules caches next to
    # its executable: the ~/.sonar/sonarqube-cli/bin link's directory on
    # macOS, the read-only store on Linux. It creates them group-writable,
    # so the directory is private.
    install -Dm0555 "$src" "$out/libexec/sonar-secrets"
    makeWrapper "$out/libexec/sonar-secrets" "$out/bin/sonar-secrets" \
      --run 'export SONAR_SECRETS_CACHE_DIR="''${SONAR_SECRETS_CACHE_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/sonar-secrets}"' \
      --run '${coreutils}/bin/mkdir -p -m 700 "$SONAR_SECRETS_CACHE_DIR"'

    runHook postInstall
  '';

  # File name the CLI looks up in ~/.sonar/sonarqube-cli/bin.
  passthru.cliBinaryName = "sonar-secrets-${version}-${release.platform}";

  meta = {
    description = "SonarSource secrets analyzer used by the SonarQube CLI";
    homepage = "https://docs.sonarsource.com/sonarqube-cli/analysis/secrets-detection";
    license = lib.licenses.unfree;
    mainProgram = "sonar-secrets";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
