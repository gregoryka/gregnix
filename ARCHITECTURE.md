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

- **CLI tools**: Runtime SOPS decryption with Nix managing the wrapper.
- **Daemons**: Linux - Use systemd-creds with LoadCredential.
- **Flatpak apps (Linux)**: Use oo7 (or desktop environment's secret service).

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

