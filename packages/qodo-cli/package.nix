{
  lib,
  stdenv,
  fetchurl,
  nodejs_26,
  makeWrapper,
  ...
}:
# Qodo ships as a single bundled qodo.mjs, resolved through
# https://get.qodo.ai/version.json (keyed by "channel": "next", "latest",
# ...) rather than a fixed release URL -- so this pins the specific
# {version, url, sha256} that endpoint returned for the `latest` channel
# rather than running the vendor install.sh, which re-resolves the latest
# release from that endpoint on every run (impure, and would drift out from
# under the Nix store). Bump version/hash here to update.
#
# The upstream installer also wires its own auto-updater (see
# QODO_DISABLE_AUTOUPDATE below); that's disabled here since this
# derivation -- not `qodo` itself -- owns the installed version.
let
  version = "2.2.0";
  channel = "latest";
in
stdenv.mkDerivation {
  pname = "qodo-cli";
  inherit version;

  src = fetchurl {
    url = "https://get.qodo.ai/releases/${version}/qodo.mjs";
    hash = "sha256-qnXikCZY9Cs5+lZpayp4nAt0lvQzkGU9wCyCdQf9pIs=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm0444 "$src" "$out/share/qodo-cli/qodo.mjs"
    makeWrapper ${lib.getExe nodejs_26} "$out/bin/qodo" \
      --add-flags "$out/share/qodo-cli/qodo.mjs" \
      --set QODO_DISABLE_AUTOUPDATE 1 \
      --set QODO_DISABLE_ANALYTICS 1

    runHook postInstall
  '';

  passthru = { inherit channel; };

  meta = {
    description = "Qodo CLI, an agentic code-review/repo-understanding tool (pinned ${channel} channel release, auto-update disabled)";
    homepage = "https://qodo.ai";
    license = lib.licenses.unfree;
    mainProgram = "qodo";
    sourceProvenance = [ lib.sourceTypes.obfuscatedCode ];
    platforms = lib.platforms.all;
  };
}
