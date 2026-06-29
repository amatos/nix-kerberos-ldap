# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `modules/ldap.nix` — `krb5Package` option; defaults to `pkgs.krb5`
  but must be set to an LDAP-enabled build (`withLdap = true`) for the
  Kerberos schema include and kldap backend to work
- `modules/kerberos.nix` — `krb5Package` option; used for `krb5kdc`,
  `kadmind` `ExecStart` paths and `environment.systemPackages`

### Fixed

- `modules/ldap.nix` — default secret paths removed erroneous
  `secrets/` subdirectory prefix; secrets live at the nix-secrets root
- `modules/ldap.nix` — `olcRootPW` changed from invalid
  `{ _secret = ... }` to `{ path = ... }` as required by
  `services.openldap.settings`
- `modules/kerberos.nix` — default secret paths removed erroneous
  `secrets/` subdirectory prefix
- `modules/ldap.nix` — Kerberos schema path now uses `cfg.krb5Package`
  instead of `pkgs.krb5`; the schema is only present in LDAP-enabled
  builds
- `modules/kerberos.nix` — `ExecStart` and `systemPackages` now use
  `cfg.krb5Package` instead of hardcoded `pkgs.krb5`
