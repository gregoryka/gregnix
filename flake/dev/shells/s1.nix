{
  lib,
  pkgs,
  ...
}:
let
  # nixpkgs' clang wrapper takes its libstdc++ headers from the default gcc, so
  # pin it to the same gcc as the runtime libstdc++ below.
  clang22 = pkgs.clang_22.override { gccForLibs = pkgs.gcc15.cc; };

  # clang22's default hardening flags, minus fortify/fortify3.
  hardeningFlags = lib.concatStringsSep " " (
    lib.subtractLists [ "fortify" "fortify3" ] clang22.defaultHardeningFlags
  );

  # nixpkgs does not expose versioned `clang-22`/`clang++-22`/`llvm-ar-22`
  # binaries directly, so alias them ourselves for convenience.
  versionedLlvmTools = pkgs.runCommand "s1-versioned-llvm-tools" { } ''
    mkdir -p "$out/bin"
    ln -s "${clang22}/bin/clang" "$out/bin/clang-22"
    ln -s "${clang22}/bin/clang++" "$out/bin/clang++-22"
    ln -s "${pkgs.llvmPackages_22.llvm}/bin/llvm-ar" "$out/bin/llvm-ar-22"
  '';

  packages = with pkgs; [
    clang22
    llvmPackages_22.llvm
    llvmPackages_22.clang-tools # clangd, clang-tidy, clang-format
    gcc15.cc.lib # libstdc++15
    versionedLlvmTools
    uncrustify
    sccache
    popt
    meson
    ninja
    gnumake
    rustc
    cargo
    clippy
    rustfmt
    rust-cbindgen
    rust-bindgen
  ];

  # Matches the fixed path set in modules/home/archetypes/work/default.nix's
  # `sops.secrets.artifactory_token.path`.
  artifactoryTokenPath = "$HOME/.local/state/sops-nix/artifactory_token";
in
pkgs.mkShellNoCC {
  inherit packages;

  shellHook = ''
    export NIX_HARDENING_ENABLE="${hardeningFlags}"


    if [[ -f "${artifactoryTokenPath}" ]]; then
      ART_TOKEN="$(cat "${artifactoryTokenPath}")"
      export ART_TOKEN
    fi
  '';
}
