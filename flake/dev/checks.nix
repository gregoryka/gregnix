{
  inputs,
  lib,
  self,
  ...
}:
{
  imports = lib.optional (inputs.git-hooks-nix ? flakeModule) inputs.git-hooks-nix.flakeModule;

  perSystem =
    { pkgs, ... }:
    {
      pre-commit = lib.mkIf (inputs.git-hooks-nix ? flakeModule) {
        check.enable = false;

        settings.hooks = {
          check-merge-conflicts = {
            enable = true;
            args = [ "--assume-in-merge" ];
          };

          convco.enable = true;

          gitleaks = {
            enable = true;
            name = "gitleaks";
            description = "Scan staged changes for secrets/PII before they can be committed";
            entry = "${pkgs.gitleaks}/bin/gitleaks git --pre-commit --staged --verbose --redact --config ${
              builtins.path {
                path = ../../.gitleaks.toml;
                name = "gitleaks.toml";
              }
            }";
            language = "system";
            pass_filenames = false;
          };

          pre-commit-hook-ensure-sops.enable = true;

          treefmt.enable = true;

          typos = {
            enable = true;
            settings.config = {
              default.extend-ignore-re = [
                # SSH public keys (ssh-rsa, ssh-ed25519, etc.)
                "ssh-[a-z0-9]+ [A-Za-z0-9+/=]+"
              ];
              files.extend-exclude = [
                "*.lock"
                "flake.lock"
                "secrets/**"
                ".sops.yaml"
                # Armored PGP keys
                "*.asc"
              ];
            };
          };
        };
      };

      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
        lib.mapAttrs' (name: cfg: {
          name = "darwin-${name}";
          value = cfg.system;
        }) self.darwinConfigurations
      );
    };
}
