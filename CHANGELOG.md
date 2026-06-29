# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `modules/ldap.nix` — `saslKeytabFile` option: age-encrypted keytab for
  the slapd `ldap/` service principal; deployed with `openldap` ownership
  so the daemon can read it (`/etc/krb5.keytab` is root-only and cannot
  be reused for this purpose)
- `modules/ldap.nix` — `saslHost` option: sets `olcSaslHost` in cn=config
  to match the hostname component of the `ldap/` service principal (e.g.
  `porkchop.ts.matos.cc`); used by Cyrus SASL to find the correct
  keytab entry during GSSAPI negotiation
- `modules/ldap.nix` — `saslAuthzRegexp` option: populates `olcAuthzRegexp`
  in cn=config; maps Kerberos principal names (presented by Cyrus SASL as
  `uid=<user>,cn=<REALM>,cn=gssapi,cn=auth`) to LDAP DNs
- `modules/ldap.nix` — `KRB5_KTNAME` set in the openldap systemd service
  environment when `saslKeytabFile` is configured; directs libkrb5 to the
  dedicated slapd keytab rather than the system default
- `modules/ldap.nix` — `listenAddresses` option: replaces the default
  `ldap://127.0.0.1/` TCP entry (while keeping `ldapi:///`); use to
  expose slapd on Tailscale/LAN so GSSAPI clients can reach it via FQDN
  (GSSAPI derives the service principal from the URL hostname, so
  clients must connect by name, not 127.0.0.1)
- `kerberos.schema` — bundled Kerberos LDAP schema (Novell/MIT) in old
  slapd.conf format; kept as the human-readable reference source
- `kerberos.ldif` — Kerberos schema in cn=config LDIF format; this is
  what `services.openldap.settings` includes feed to `slapadd` via
  `include: file://` directives; static file avoids the operational
  attributes (`entryUUID`, `creatorsName`, etc.) that `slaptest -F`
  injects and that cause slapadd to fail
- `modules/ldap.nix` — `ldapi:///` added to urlList; `olcDatabase={0}config`
  added with ACL granting root SASL EXTERNAL manage rights on cn=config;
  together these allow `ldapmodify -Y EXTERNAL -H ldapi:///` to correct
  olcRootPW post-initialization (the `{ path = ... }` value includes a
  trailing newline that breaks simple bind authentication)
- `modules/kerberos.nix` — `krb5Package` option; used for `krb5kdc`,
  `kadmind` `ExecStart` paths and `environment.systemPackages`
- `modules/kerberos.nix` — `ldapServicePasswordFile` option (default
  `/var/lib/krb5kdc/service.keyfile`); separates the binary stash file
  path from the age-encrypted plaintext secret — MIT Kerberos requires
  the binary stash format written by `kdb5_ldap_util stashsrvpw`, not
  the raw plaintext password

### Fixed

- `modules/ldap.nix` — `listenAddresses` now replaces the default
  `ldap://127.0.0.1/` TCP entry rather than appending to it; appending
  `ldap://0.0.0.0/` alongside `ldap://127.0.0.1/` caused slapd to
  attempt binding port 389 twice (errno=98, Address already in use)
- `modules/kerberos.nix` — `LogsDirectory = "krb5"` added to kadmind
  service so it can write to `/var/log/krb5/kadmin.log` (was only set
  on kdc.service)
- `modules/kerberos.nix` — `kadm5.acl` written to `/etc/krb5kdc/kadm5.acl`
  granting `*/admin@<realm>` full rights; `[kadmin] acl_file` added to
  krb5.conf pointing kadmind at that path (default is
  `/var/lib/krb5kdc/kadm5.acl` which is not managed by NixOS)
- `modules/ldap.nix` — Kerberos subtree ACL now grants write to both
  `cn=kdc` and `cn=kadmin`; granting only `cn=kdc` caused kadmind and
  `kadmin.local` to fail with "Unable to read Realm: No such object"
  because `cn=kadmin` fell through to `by * none`
- `modules/ldap.nix` — `mutableConfig = true` added; without this the NixOS
  openldap module runs `chmod -R u+r-w` on slapd.d after every activation,
  making all cn=config files read-only and causing any `ldapmodify` to fail
  with error (80) `LDAP_OTHER` when the backend tries to persist the change
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
