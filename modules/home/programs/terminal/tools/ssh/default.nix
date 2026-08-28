{
  config,
  lib,

  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    concatStringsSep
    concatMapStringsSep
    concatLists
    mapAttrs'
    mapAttrsToList
    nameValuePair
    filterAttrs
    optionalString
    ;
  inherit (lib.gregnix) mkOpt;

  cfg = config.gregnix.programs.terminal.tools.ssh;

  hostPatternOf = name: host: if host.hostPattern != null then host.hostPattern else name;

  knownHostsKeyOf =
    name: host: if host.hostName != null then host.hostName else hostPatternOf name host;

  mkHostBlock = name: host: ''
    Host ${hostPatternOf name host}
    ${optionalString (host.hostName != null) "  HostName ${host.hostName}"}
    ${optionalString (host.user != null) "  User ${host.user}"}
    ${optionalString (host.identityAgent != null) "  IdentityAgent \"${host.identityAgent}\""}
    ${optionalString (
      host.publicKey != ""
    ) "  IdentityFile \"${config.xdg.configHome}/ssh/${name}.pub\""}
    ${optionalString host.identitiesOnly "  IdentitiesOnly yes"}
    ${concatMapStringsSep "\n" (
      fwd: "  RemoteForward \"${fwd.remote}\" \"${fwd.local}\""
    ) host.remoteForwards}
  '';
in
{
  options.gregnix.programs.terminal.tools.ssh = {
    enable = mkEnableOption "SSH";

    authorizedKeys = mkOpt (types.listOf types.str) [ ] "Public keys allowed to SSH into this machine.";

    extraConfig = mkOpt types.lines "" ''
      Extra ssh_config text, rendered via sops and pulled in with `Include`
      so values containing a `sops.placeholder` (e.g. a sensitive
      `HostName`) don't land in the plaintext Nix store.
    '';

    extraKnownHosts = mkOpt (types.listOf types.str) [ ] ''
      Extra `known_hosts` lines, in addition to the built-in ones, rendered
      via sops so entries containing a `sops.placeholder` (e.g. a sensitive
      hostname) don't land in the plaintext Nix store.
    '';

    identityFiles = mkOpt (types.attrsOf types.str) { } ''
      Public key contents (not secret) to materialize at
      `$XDG_CONFIG_HOME/ssh/<name>`, keyed by filename, so an
      `IdentityFile` directive elsewhere can point at a stable path
      instead of e.g. an app sandbox container path directly.
    '';

    secretiveSocket = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.home.homeDirectory}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      description = ''
        Path to the Secretive (macOS Secure Enclave) agent's fixed sandbox
        socket.
      '';
    };

    hosts =
      mkOpt
        (types.attrsOf (
          types.submodule {
            options = {
              hostPattern = mkOpt (types.nullOr types.str) null ''
                Override for the literal `Host` pattern text -- defaults to
                this attribute's own name. Needed when the name itself must
                stay a plain, eval-time-safe string (it's also what
                `identityFiles`/`IdentityFile` materialize the public key
                filename from) but the real ssh `Host` pattern is a
                `sops.placeholder.*` value -- set the attribute name to a
                safe alias and this to the placeholder.
              '';

              hostName = mkOpt (types.nullOr types.str) null "Optional `HostName` directive.";

              user = mkOpt (types.nullOr types.str) null "Optional `User` directive.";

              identityAgent = mkOpt (types.nullOr types.str) null ''
                Optional `IdentityAgent` socket path (e.g. `secretiveSocket`
                above, or `_1password-cli.sshSocket`).
              '';

              publicKey = mkOpt types.str "" ''
                Public key content (not secret) for this host's identity, if
                any. When set, materialized to `$XDG_CONFIG_HOME/ssh/<name>.pub`
                (via `identityFiles`) and referenced by this Host block's
                `IdentityFile`. Leave unset for agent-only auth (e.g.
                a client that can't handle `IdentityFile` pointing at a
                public key, only an agent offering one).
              '';

              identitiesOnly = mkOpt types.bool false ''
                Whether to restrict this Host to only the identity above
                (`IdentitiesOnly yes`) -- e.g. so a host with a strict
                auth-attempt limit (like github.com) isn't offered every
                other key loaded into the same agent.
              '';

              remoteForwards =
                mkOpt
                  (types.listOf (
                    types.submodule {
                      options = {
                        local = mkOpt types.str "" ''
                          Local socket path/address to forward -- the second
                          argument to `RemoteForward`.
                        '';
                        remote = mkOpt types.str "" ''
                          Path/address on the remote host that `local` is
                          forwarded to -- the first (bind) argument to
                          `RemoteForward`.
                        '';
                      };
                    }
                  ))
                  [ ]
                  ''
                    `RemoteForward` entries for this Host.
                  '';

              hostKeys = mkOpt (types.listOf types.str) [ ] ''
                SSH host public keys (e.g. from `ssh-keyscan`) for this
                Host; public, not secret. Contributes a "<address> <key>"
                line to `extraKnownHosts` for each -- keyed by `hostName`
                if set, else by `hostPattern`/this attribute's name -- so a
                Host's connection config and its known-hosts pinning are
                declared together rather than drifting apart in two
                different places.
              '';
            };
          }
        ))
        { }
        ''
          SSH `Host` blocks, keyed by ssh alias/hostname pattern. Handles
          materializing the public key (if any) and wiring
          `IdentityAgent`/`IdentityFile`/`RemoteForward`/`IdentitiesOnly`
          consistently, rather than every consumer hand-rolling the same
          `Host` block shape.
        '';
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Rendered unconditionally (content may be empty) so their presence in
      # `sops.templates` never depends on `cfg.extraConfig`/`extraKnownHosts`,
      # which themselves may read `sops.placeholder.*` -- placeholders only
      # become available once `sops.templates != {}`, so gating these template
      # *keys* on the same values would be a dependency cycle.
      sops.templates = {
        "ssh-extra-config".content = cfg.extraConfig;
        "ssh-extra-known-hosts".content = concatStringsSep "\n" cfg.extraKnownHosts;
      };

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [ config.sops.templates."ssh-extra-config".path ];

        settings."*" = {
          AddKeysToAgent = "yes";
          ForwardAgent = false;
          # Our known_hosts entries are hostname-keyed; without this, an ssh
          # older/newer than nixpkgs' default could also try (and fail) to
          # verify the resolved IP separately.
          CheckHostIP = false;
          ServerAliveInterval = 30;
          ServerAliveCountMax = 2;
          StreamLocalBindUnlink = "yes";
          ConnectTimeout = 5;
          ControlMaster = "auto";
          ControlPath = "~/.ssh/controlmasters/%C";
          ControlPersist = "10m";
          # "~/.ssh/known_hosts" stays a regular, user-writable file so
          # normal TOFU prompts still work; the nix-managed entries live in
          # a separate file since `home.file`/`xdg.configFile` are
          # read-only store symlinks.
          UserKnownHostsFile = [
            "~/.ssh/known_hosts"
            config.sops.templates."ssh-extra-known-hosts".path
          ];
        };
      };

      home.file.".ssh/controlmasters/.keep".text = "";

      # Some clients (e.g. Claude Desktop's embedded ssh2 client)
      # only ever check the literal `~/.ssh/known_hosts`, ignoring the second
      # `UserKnownHostsFile` path above entirely. Merge the nix-managed entries
      # into it too.
      home.activation.syncNixKnownHosts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run install -d -m700 "$HOME/.ssh"
        run touch "$HOME/.ssh/known_hosts"
        extraKnownHosts="${config.sops.templates."ssh-extra-known-hosts".path}"
        if [[ -s "$extraKnownHosts" ]]; then
          while IFS= read -r hostKeyLine || [[ -n "$hostKeyLine" ]]; do
            [[ -z "$hostKeyLine" ]] && continue
            grep -qxF "$hostKeyLine" "$HOME/.ssh/known_hosts" || echo "$hostKeyLine" >> "$HOME/.ssh/known_hosts"
          done < "$extraKnownHosts"
        fi
      '';
    }

    (mkIf (cfg.identityFiles != { }) {
      xdg.configFile = mapAttrs' (
        name: content: nameValuePair "ssh/${name}" { text = content; }
      ) cfg.identityFiles;
    })

    (mkIf (cfg.hosts != { }) {
      gregnix.programs.terminal.tools.ssh = {
        identityFiles = mapAttrs' (name: host: nameValuePair "${name}.pub" host.publicKey) (
          filterAttrs (_name: host: host.publicKey != "") cfg.hosts
        );

        extraConfig = concatStringsSep "\n" (mapAttrsToList mkHostBlock cfg.hosts);

        extraKnownHosts = concatLists (
          mapAttrsToList (
            name: host: map (key: "${knownHostsKeyOf name host} ${key}") host.hostKeys
          ) cfg.hosts
        );
      };
    })

    (mkIf (cfg.authorizedKeys != [ ]) {
      # Deliberately NOT `home.file`: that symlinks into the Nix store, and
      # sshd's StrictModes then refuses the key ("bad ownership or modes for
      # directory /nix/store", since the store is group-writable) -- silently
      # falling back to password auth. Materialize a real, plain file instead.
      home.activation.installAuthorizedKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run install -d -m700 "$HOME/.ssh"
        cat > "$HOME/.ssh/authorized_keys" <<'EOF'
        ${concatStringsSep "\n" cfg.authorizedKeys}
        EOF
        run chmod 600 "$HOME/.ssh/authorized_keys"
      '';
    })
  ]);
}
