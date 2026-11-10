# **Multi-Platform Nix Flake Architecture Guideline**

This document outlines a standardized architecture for a multi-platform Nix Flake, integrating NixOS, nix-darwin, and Home Manager with a primary focus on secure secrets management.

# **Secrets Management Strategy**

Secrets management must be categorized by the machine's role, the data's sensitivity, and its lifecycle. We use a tiered approach to balance security and usability.

## **Security Sources**

Wherever possible, prioritize hardware security over software-based management.

- **macOS**: Secure Enclave.  
- **PC/Linux**: TPM, Nitrokey.

## **Categorization & Handling**

### **1\. Privacy Secrets (Reconnaissance Deterrence)**

These secrets include personal data (e.g., email addresses) and infrastructure details (e.g., internal IPs, internal URLs). While they lack inherent security value (access credentials), they provide an attacker with a map of the environment.

- **Handling**: Encrypted in the flake via `sops`. Upon arrival at the machine, they are rendered into RAM-backed config files (e.g., via `sops.templates` in `sops-nix`).  
- **Threat Model**: Access to these files requires persistent disk read access while the machine is running, which implies a significantly compromised system state.

### **2\. Security Secrets (Access Credentials)**

These include private keys, passwords, and access tokens that grant direct system access. Their protection must minimize disk/RAM exposure.

- **Handling**: Avoid RAM-backed files where possible. Prefer process injection.

#### **Tools & Enforcement**

- **CLI tools**: Runtime SOPS decryption with Nix managing the wrapper, unless the tool qualifies for its own keychain storage (see below).
- **Daemons**: Linux - Use systemd-creds with LoadCredential.
- **Flatpak apps (Linux)**: Use oo7 (or desktop environment's secret service).

#### **Executable-Bound Keychain Storage (macOS)**

SOPS decryption and `/usr/bin/security`-readable keychain items are available to any process running as the user. A macOS keychain item can instead be bound to a single executable, so other processes get an approval dialog rather than the secret. Prefer the tool's own keychain storage (e.g. `<tool> auth login`) over a SOPS wrapper when the executable meets both requirements:

1. **Calls the Security framework directly.** The item's ACL then trusts the tool itself. Tools that shell out to `/usr/bin/security` (e.g. `gh`) produce items any process can read.
2. **Has a stable code-signing identity.** A Developer ID (or other certificate-anchored) signature yields a designated requirement that survives updates and Nix store path changes. Ad-hoc signed binaries (most Nix-built tools, e.g. `jk`) are bound by cdhash, so every rebuild invalidates the ACL and triggers an approval dialog that blocks agents.

Optional nice-to-haves (not enforced by the Security framework, but they strengthen the binding):

- **Hardened runtime.** Blocks `DYLD_INSERT_LIBRARIES` and debugger attachment, which could otherwise run code inside the trusted process and read the secret.
- **Does not hand the secret out.** No command (e.g. `<tool> auth token`) or debug output that prints the stored credential, no passing it to child processes (e.g. via environment variables), and no unauthenticated configuration (proxies, CA certificates, alternative server URLs) that redirects where it is sent.

The Nix package must also leave the vendor signature intact; verify with `codesign -v --strict` and `codesign -dv` (look for a `TeamIdentifier`, and `flags=0x10000(runtime)` for the hardened runtime). Install such tools unwrapped, since the ACL is checked against the process that reads the item.

This protects the raw secret, not its use: any process can still run the tool. Linux has no equivalent per-executable binding; isolation there requires a separate user or a sandbox.

Assessed tools:

- `sonar` (sonarqube-cli 1.11): meets both requirements and has the hardened runtime, but does hand the secret out. It passes the token to its MCP container via `SONARQUBE_TOKEN` in the container runtime's environment, and `sonar config set` can change the proxy, CA certificate and `mcp.container.serverUrl` without authentication. Keychain storage still prevents trivially reading the token, but does not stop a determined same-user process from obtaining it.
- `gh`: fails 1 (uses `/usr/bin/security`); use SOPS.
- `jk` (0.0.45 upstream release binary): meets both requirements and has the hardened runtime (a Nix source build is ad-hoc signed and fails 2, so the package installs the release binary on macOS). It does hand the secret out: `config.yaml` sets the controller URL, proxy, CA certificate and `insecure` without authentication. On Linux it reads its token from `JK_TOKEN`, decrypted from SOPS by a wrapper.

#### **Token Naming Convention**

When creating a new token (a 1Password item, an API key, etc.), name it using:

```
[Scope/Machine]-[Service]-[Purpose]-[Type]
```

| Segment | Description | Example values |
| :---- | :---- | :---- |
| **Scope/Machine** | Where the token may be used: `global` if shared across every host, otherwise the specific hostname it's restricted to. | `global`, `vm`, `mac` |
| **Service** | The external system/API the token authenticates to. | `qodo`, `artifactory`, `github` |
| **Purpose** | What consumes the token -- the client, workflow, or access level it's scoped to. | `cli`, `npm`, `ci`, `readonly` |
| **Type** | The token's shape/kind. | `key`, `token`, `credential`, `pat` |

Examples:

- `global-qodo-cli-key` -- Qodo CLI API key, shared across every machine.
- `vm-artifactory-npm-token` -- Artifactory token scoped to npm registry auth, only used in the vm.

## **Implementation Guidelines**

- **Nix Store Leak Protection**: Never write secrets via standard `home.file` declarations. Always use `sops.templates` to render sensitive data to RAM-backed paths (e.g., `/run/user/1000/`) to prevent leaking plaintext into the world-readable Nix store.  
- **Lifecycle Management**: Use `systemd-tmpfiles` (Linux) and `launchd` agents (macOS) for dynamic cache cleanup of mutable tokens, ensuring no orphaned credentials persist on physical disk.

