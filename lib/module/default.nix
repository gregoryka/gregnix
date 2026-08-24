{ inputs }:
let

  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    mkOption
    types
    toUpper
    mkDefault
    mkForce
    ;

  base64Lib = import ../base64 { inherit inputs; };
in
rec {
  /**
    Enable a module with optional configuration.

    # Inputs

    `module`

    : 1\. Function argument

    `config`

    : 2\. Function argument
  */
  enable =
    module: config:
    {
      imports = [ module ];
    }
    // config;

  /**
    Conditionally enable modules based on system.

    # Inputs

    `system`

    : 1\. Function argument

    `modules`

    : 2\. Function argument
  */
  enableForSystem =
    system: modules:
    builtins.filter (
      mod: mod.systems or [ ] == [ ] || builtins.elem system (mod.systems or [ ])
    ) modules;

  # Option creation helpers

  /**
    Create a nixpkgs option.

    # Inputs

    `type`

    : 1\. Function argument

    `default`

    : 2\. Function argument

    `description`

    : 3\. Function argument
  */
  mkOpt =
    type: default: description:
    mkOption { inherit type default description; };

  /**
    Create a nixpkgs option without a description.

    # Inputs

    `type`

    : 1\. Function argument

    `default`

    : 2\. Function argument
  */
  mkOpt' = type: default: mkOpt type default null;

  /**
    Create a boolean nixpkgs option.

    # Inputs

    `type`

    : 1\. Function argument

    `default`

    : 2\. Function argument

    `description`

    : 3\. Function argument
  */
  mkBoolOpt = mkOpt types.bool;

  /**
    Generic ARCHITECTURE.md-compliant secrets injection: wraps an existing
    executable so that, at invocation time (never at build time), named
    environment variables are populated either by re-execing once through
    `op run` against a 1Password reference (primary, for CLI tools) or by
    decrypting a sops field fresh on every invocation (fallback: "runtime
    SOPS decryption with Nix managing the wrapper", for hosts without
    1Password). Both mechanisms only ever expose the *resolved* value to
    the wrapped process's environment -- never to disk or the Nix store;
    the op:// references and sops file paths baked into the script are
    pointers, not secrets. Takes `pkgs` explicitly (for
    `writeShellApplication`/`sops`) since this file is pure `lib`, with no
    instantiated `pkgs` of its own.

    # Inputs

    `pkgs`
    : nixpkgs instance, for `writeShellApplication` and `sops`.

    `executable`
    : The real executable to wrap, e.g. `lib.getExe somePackage`.

    `name`
    : Name for the resulting wrapper (usually matching the wrapped program).

    `opEnv`
    : attrsOf str -- ENV_VAR -> op:// reference, injected via a single
      `op run` re-exec. Defaults to `{ }`.

    `sopsEnv`
    : attrsOf `{ sopsFile :: path; key :: str; }` -- ENV_VAR -> sops
      field, decrypted fresh on every invocation via
      `sops decrypt --extract`. Defaults to `{ }`.

    `noMaskingCommands`
    : listOf str -- subcommand prefixes (e.g. `[ "auth token" ]`,
      matched word-for-word against the wrapped command's leading
      positional args) that legitimately print a secret as their real
      output -- a credential-helper protocol, a `<tool> token`-style
      command, etc. -- and therefore need `op run --no-masking` for that
      invocation specifically. `op run` masks (redacts to `[CONCEALED]`)
      any injected secret it sees in the wrapped process's stdout/stderr
      by default; every invocation not matching an entry here keeps that
      default, so secrets that leak into output some other way (verbose
      logging, error dumps) still get redacted. Defaults to `[ ]`
      (always masked).
  */
  mkSecretsWrapper =
    {
      pkgs,
      executable,
      name,
      opEnv ? { },
      sopsEnv ? { },
      noMaskingCommands ? [ ],
    }:
    let
      opRunArgs = lib.concatStringsSep " " (
        lib.mapAttrsToList (envVar: ref: ''"${envVar}=${ref}"'') opEnv
      );

      sopsExports = lib.concatStrings (
        lib.mapAttrsToList (envVar: secret: ''
          ${envVar}="$(sops decrypt --extract '["${secret.key}"]' "${secret.sopsFile}")"
          export ${envVar}
        '') sopsEnv
      );

      # `${1:-}`, `${2:-}`, ... as literal bash text -- built via string
      # concatenation (not `''${...}` string interpolation escapes) since
      # the positional index is only known once `lib.imap0` below runs.
      positional = n: "\${" + toString n + ":-}";

      # One `(( "${1:-}" == "word1" && "${2:-}" == "word2" ))`-style group
      # per `noMaskingCommands` entry, matching its words against the
      # wrapped command's leading positional args.
      argMatch =
        cmd:
        "("
        + lib.concatStringsSep " && " (
          lib.imap0 (i: word: ''"${positional (i + 1)}" == "${word}"'') (lib.splitString " " cmd)
        )
        + ")";

      noMaskingCheck = lib.concatStringsSep " || " (map argMatch noMaskingCommands);
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = lib.optional (sopsEnv != { }) pkgs.sops;
      text =
        lib.optionalString (opEnv != { }) ''
          # 1Password (ARCHITECTURE.md primary for CLI tools): re-exec once
          # through `op run`, which resolves each op:// reference below to
          # its real value and injects it only into this process's
          # environment.
          if [[ -z "''${_OP_RUN_ACTIVE:-}" ]]; then
            export _OP_RUN_ACTIVE=1
            maskingFlag=()
            ${lib.optionalString (noMaskingCommands != [ ]) ''
              if [[ ${noMaskingCheck} ]]; then
                maskingFlag=(--no-masking)
              fi
            ''}
            exec env ${opRunArgs} op run "''${maskingFlag[@]}" -- "$0" "$@"
          fi
        ''
        + lib.optionalString (sopsEnv != { }) ''
          # ARCHITECTURE.md fallback (1Password unavailable): runtime sops
          # decryption with Nix managing the wrapper.
          ${sopsExports}
        ''
        + ''
          exec "${executable}" "$@"
        '';
      meta.mainProgram = name;
    };

  /**
    Create a boolean nixpkgs option without a description.

    # Inputs

    `type`

    : 1\. Function argument

    `default`

    : 2\. Function argument
  */
  mkBoolOpt' = mkOpt' types.bool;

  /**
    Standard enabled pattern.
  */
  enabled = {
    enable = true;
  };

  /**
    Standard disabled pattern.
  */
  disabled = {
    enable = false;
  };

  /**
    Capitalize a string.

    # Inputs

    `s`

    : 1\. Function argument
  */
  capitalize =
    s:
    let
      len = lib.stringLength s;
    in
    if len == 0 then "" else (toUpper (lib.substring 0 1 s)) + (lib.substring 1 len s);

  /**
    Convert a boolean to a number.

    # Inputs

    `bool`

    : 1\. Function argument
  */
  boolToNum = bool: if bool then 1 else 0;

  /**
    Package profile tiers, from smallest to broadest payload.
  */
  packageProfiles = [
    "core"
    "standard"
    "maximal"
  ];

  /**
    Package profile option type.
  */
  packageProfileType = types.enum packageProfiles;

  /**
    Package profile ranks for inclusion checks.
  */
  packageProfileRank = {
    core = 0;
    standard = 1;
    maximal = 2;
  };

  /**
    Whether an active package profile includes a tier.
  */
  profileIncludes = active: tier: packageProfileRank.${active} >= packageProfileRank.${tier};

  /**
    Standard suite package profile override option.
  */
  mkPackageProfileOption = description: mkOpt (types.nullOr packageProfileType) null description;

  /**
    Resolve a package profile override against a global default.
  */
  resolvePackageProfile = global: override: if override == null then global else override;

  /**
    Resolve a suite package profile from module config and suite config.
  */
  suitePackageProfile =
    config: suiteCfg: resolvePackageProfile config.gregnix.packageProfile suiteCfg.packageProfile;

  /**
    Whether a suite's effective package profile includes a tier.
  */
  suiteProfileIncludes = config: suiteCfg: profileIncludes (suitePackageProfile config suiteCfg);

  /**
    Apply mkDefault to all attributes in a set.

    # Inputs

    `set`

    : 1\. Function argument
  */
  default-attrs = lib.mapAttrs (_key: mkDefault);

  /**
    Apply mkForce to all attributes in a set.

    # Inputs

    `set`

    : 1\. Function argument
  */
  force-attrs = lib.mapAttrs (_key: mkForce);

  /**
    Apply default-attrs to nested attribute sets.

    # Inputs

    `set`

    : 1\. Function argument
  */
  nested-default-attrs = lib.mapAttrs (_key: default-attrs);

  /**
    Apply force-attrs to nested attribute sets.

    # Inputs

    `set`

    : 1\. Function argument
  */
  nested-force-attrs = lib.mapAttrs (_key: force-attrs);
}
// base64Lib
