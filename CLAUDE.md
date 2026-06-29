# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is a NixOS flake that provides a Kerberos (MIT Kerberos / `krb5`) environment backed by an LDAP directory (OpenLDAP). It is designed to be imported into an existing NixOS system configuration, not used standalone. The flake exposes NixOS modules that configure both the KDC and LDAP server together.

## Secrets Management

All secrets (Kerberos master key, LDAP admin password, service keytabs, TLS certificates, etc.) are stored in and referenced from the sibling project **`~/Projects/nix-secrets`**. That project is a separate git repo and should never have secrets inlined here. Reference secrets from `nix-secrets` using its flake output or `sops-nix` / `agenix` patterns — whichever convention `nix-secrets` uses — rather than hardcoding paths.

## Flake Structure Conventions

- `flake.nix` — the entry point; exposes `nixosModules` outputs (at minimum a top-level module and per-component modules for Kerberos and LDAP)
- `modules/` — NixOS module files, one per logical component (e.g., `kdc.nix`, `ldap.nix`, `kerberos-ldap-backend.nix`)
- `lib/` — helper functions if needed (LDIF generation, schema helpers, etc.)
- Avoid adding a `pkgs` overlay unless strictly necessary; prefer using packages from the consumer's `nixpkgs` input

## Key Integration Points

- **LDAP as KDC backend**: MIT Kerberos is configured to use the LDAP backend (`kldap`). This requires the `krb5-kdc-ldap` schema loaded into OpenLDAP and the KDC's LDAP service account credentials stored in `nix-secrets`.
- **NixOS service options**: Modules should expose a clean `options` namespace (e.g., `services.kerberosLdap`) so the consumer's NixOS config only needs to set realm name, domain, LDAP base DN, and a reference to their `nix-secrets` input.
- **Ordering**: The LDAP service must be fully started and the schema loaded before the KDC starts. Use `after`/`requires`/`wantedBy` systemd dependencies accordingly.

## Nix Conventions

- Use `lib.mkOption` with `description`, `type`, and `default` for all module options
- Prefer `lib.mkIf` / `lib.mkMerge` for conditional config blocks
- Format all `.nix` files with `nixpkgs-fmt` or `alejandra` (decide and stay consistent)
- Lock `flake.lock` and commit it; do not add `flake.lock` to `.gitignore`
