{
  inputs,
  ...
}:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        flakeCheck = true;
        flakeFormatter = true;

        projectRootFile = "flake.nix";

        programs = {
          actionlint.enable = true;
          deadnix = {
            enable = true;
            no-lambda-arg = true;
          };
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          statix = {
            enable = true;
            priority = -2;
          };
          zizmor.enable = true;
        };

        settings = {
          global.excludes = [
            "*.lock"
            "flake.lock"
            ".git/*"
          ];
        };
      };
    };
}
