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
    environment variables are populated by decrypting a sops field fresh
    on every invocation ("runtime SOPS decryption with Nix managing the
    wrapper"). Only the *resolved* value is ever exposed, and only to the
    wrapped process's environment -- never to disk or the Nix store; the
    sops file paths baked into the script point at ciphertext, not
    secrets. Takes `pkgs` explicitly (for
    `writeShellApplication`/`sops`) since this file is pure `lib`, with no
    instantiated `pkgs` of its own.

    # Inputs

    `pkgs`
    : nixpkgs instance, for `writeShellApplication` and `sops`.

    `executable`
    : The real executable to wrap, e.g. `lib.getExe somePackage`.

    `name`
    : Name for the resulting wrapper (usually matching the wrapped program).

    `sopsEnv`
    : attrsOf `{ sopsFile :: path; key :: str; }` -- ENV_VAR -> sops
      field, decrypted fresh on every invocation via
      `sops decrypt --extract`.

    `env`
    : attrsOf str -- ENV_VAR -> fixed, non-secret value, exported
      before the sops fields. Defaults to `{ }`.
  */
  mkSecretsWrapper =
    {
      pkgs,
      executable,
      name,
      sopsEnv,
      env ? { },
    }:
    let
      envExports = lib.concatStrings (
        lib.mapAttrsToList (envVar: value: ''
          export ${lib.toShellVar envVar value}
        '') env
      );

      sopsExports = lib.concatStrings (
        lib.mapAttrsToList (envVar: secret: ''
          ${envVar}="$(sops decrypt --extract '["${secret.key}"]' "${secret.sopsFile}")"
          export ${envVar}
        '') sopsEnv
      );
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.sops ];
      text = ''
        ${envExports}${sopsExports}
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
