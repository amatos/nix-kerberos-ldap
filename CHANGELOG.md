# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `kerberos.schema` — bundled Kerberos LDAP schema (Novell/MIT) in old
  slapd.conf format; kept as the human-readable reference source
- `kerberos.ldif` — Kerberos schema in cn=config LDIF format; this is
  what `services.openldap.settings` includes feed to `slapadd` via
  `include: file://` directives; static file avoids the operational
  attributes (`entryUUID`, `creatorsName`, etc.) that `slaptest -F`
  injects and that cause slapadd to fail
- `modules/kerberos.nix` — `krb5Package` option; used for `krb5kdc`,
  `kadmind` `ExecStart` paths and `environment.systemPackages`
- `modules/kerberos.nix` — `ldapServicePasswordFile` option (default
  `/var/lib/krb5kdc/service.keyfile`); separates the binary stash file
  path from the age-encrypted plaintext secret — MIT Kerberos requires
  the binary stash format written by `kdb5_ldap_util stashsrvpw`, not
  the raw plaintext password

### Fixed

- `modules/ldap.nix` — default secret paths removed erroneous
  `secrets/` subdirectory prefix; secrets live at the nix-secrets root
- `modules/ldap.nix` — `olcRootPW` changed from invalid
  `{ _secret = ... }` to `{ path = ... }` as required by
  `services.openldap.settings`
- `modules/kerberos.nix` — default secret paths removed erroneous
  `secrets/` subdirectory prefix
- `modules/ldap.nix` — Kerberos schema include now uses
  `${../kerberos.ldif}` (static cn=config LDIF); removed `krb5Package`
  option (was only used for the no-longer-referenced nixpkgs schema
  path); the `.schema` format fails with `str2entry: entry -1 has no dn`
  and the `slaptest -F` LDIF fails with `not configured to hold
  'cn=kerberos'` due to injected operational attributes
- `modules/kerberos.nix` — `ExecStart` and `systemPackages` now use
  `cfg.krb5Package` instead of hardcoded `pkgs.krb5`
