# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `kerberos.schema` — bundled Kerberos LDAP schema (Novell/MIT); nixpkgs
  does not install this file even with `krb5.override { withLdap = true }`
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
- `modules/ldap.nix` — Kerberos schema converted to cn=config LDIF at
  build time via `pkgs.runCommand` + `slaptest`; NixOS's openldap
  module feeds `includes` to `slapadd` which requires LDIF format — the
  old `.schema` format caused `str2entry: entry -1 has no dn` failures;
  removed `krb5Package` option (was only used for the now-non-existent
  nixpkgs schema path)
- `modules/kerberos.nix` — `ExecStart` and `systemPackages` now use
  `cfg.krb5Package` instead of hardcoded `pkgs.krb5`
