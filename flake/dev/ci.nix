{
  perSystem =
    { pkgs, system, ... }:
    let
      mkApp = drv: {
        type = "app";
        program = pkgs.lib.getExe drv;
        meta = { inherit (drv.meta) description; };
      };

      # Markdown `dix diff` between <base-ref>'s and the working tree's
      # system/home closures (the `darwin-*` and `home-*` checks) for this
      # system.
      closure-diff = pkgs.writeShellApplication {
        name = "closure-diff";
        runtimeInputs = [
          pkgs.git
          pkgs.jq
          pkgs.dix
        ];
        runtimeEnv.CHECKS_SYSTEM = system;
        text = builtins.readFile ./ci/closure-diff.sh;
        meta.description = "Print a dix closure diff against a base git ref as Markdown";
      };

      # Markdown table of the root flake inputs whose locked revision differs
      # between <base-ref>'s flake.lock and the working tree's.
      input-changes = pkgs.writeShellApplication {
        name = "input-changes";
        runtimeInputs = [
          pkgs.git
          pkgs.jq
        ];
        runtimeEnv.INPUT_CHANGES_JQ = "${./ci/input-changes.jq}";
        text = builtins.readFile ./ci/input-changes.sh;
        meta.description = "Print the flake inputs changed since a base git ref as Markdown";
      };
    in
    {
      apps = {
        closure-diff = mkApp closure-diff;
        input-changes = mkApp input-changes;
      };
    };
}
