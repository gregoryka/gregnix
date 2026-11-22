{ inputs, ... }:
{
  # Builds a github:raycast/extensions extension with vicinae's builder. The
  # caller vendors the extension's package.json and package-lock.json from
  # `rev`: reading them from the fetched source instead would be
  # import-from-derivation, which breaks evaluating on another system or
  # without building. The build fails if the vendored copies drift from the
  # source.
  mkExtension =
    pkgs:
    {
      name,
      rev,
      packageJson,
      packageLock,
      ...
    }@args:
    inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkRayCastExtension (
      removeAttrs args [
        "packageJson"
        "packageLock"
      ]
      // {
        npmDeps = pkgs.importNpmLock {
          package = pkgs.lib.importJSON packageJson;
          packageLock = pkgs.lib.importJSON packageLock;
        };
        npmConfigHook = pkgs.importNpmLock.npmConfigHook;

        postPatch = ''
          if ! cmp -s package.json ${packageJson} || ! cmp -s package-lock.json ${packageLock}; then
            echo "raycast-${name}: the vendored package.json or package-lock.json differs from the source at ${rev}; recopy them" >&2
            exit 1
          fi
        ''
        + (args.postPatch or "");

        meta = {
          homepage = "https://github.com/raycast/extensions/tree/${rev}/extensions/${name}";
          license = pkgs.lib.licenses.mit;
        }
        // (args.meta or { });
      }
    );
}
