{ config, lib, pkgs, nix-secrets, ... }:

let
  cfg = config.services.kerberosLdap.ldap;
in {
  options.services.kerberosLdap.ldap = {
    enable = lib.mkEnableOption "OpenLDAP server with Kerberos schema";

    baseDN = lib.mkOption {
      type    = lib.types.str;
      example = "dc=example,dc=com";
      description = "LDAP base distinguished name.";
    };

    domain = lib.mkOption {
      type    = lib.types.str;
      example = "example.com";
      description = "Domain name (used to derive baseDN if not set explicitly).";
    };

    port = lib.mkOption {
      type    = lib.types.port;
      default = 389;
      description = "Port for slapd to listen on.";
    };

    listenAddresses = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra LDAP URLs for slapd to listen on, in addition to
        ldap://127.0.0.1:<port>/ and ldapi:///.  Use to expose slapd on
        the Tailscale or LAN interface so that remote clients and GSSAPI
        can reach it via the FQDN.  Example:
          [ "ldap://0.0.0.0:389/" ]
      '';
    };

    adminPasswordFile = lib.mkOption {
      type        = lib.types.path;
      description = "Path to the age-encrypted file containing the LDAP admin password (from nix-secrets).";
      default     = "${nix-secrets}/ldap-admin-password.age";
    };

    kdcPasswordFile = lib.mkOption {
      type        = lib.types.path;
      description = "Path to the age-encrypted file containing the KDC service account password (from nix-secrets).";
      default     = "${nix-secrets}/ldap-kdc-password.age";
    };

    tlsCertFile = lib.mkOption {
      type        = lib.types.nullOr lib.types.path;
      default     = null;
      description = ''
        Path to the TLS certificate file (fullchain) for slapd LDAPS.
        Must be readable by the openldap user at runtime — typically
        deployed by a certbot hook into a directory owned by openldap.
        When set, olcTLSCertificateFile is added to cn=config on
        initial setup; on an existing slapd apply via ldapmodify.
      '';
    };

    tlsKeyFile = lib.mkOption {
      type        = lib.types.nullOr lib.types.path;
      default     = null;
      description = ''
        Path to the TLS private key file for slapd LDAPS.  Must be
        readable by the openldap user.  Set together with tlsCertFile.
      '';
    };

    saslKeytabFile = lib.mkOption {
      type        = lib.types.nullOr lib.types.path;
      default     = null;
      description = ''
        Path to the age-encrypted keytab for slapd SASL/GSSAPI (the
        ldap/ service principal).  Deployed with openldap ownership so
        slapd can read it at runtime.  The host keytab
        (/etc/krb5.keytab) is not usable here because slapd does not
        run as root.
      '';
    };

    saslHost = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = ''
        Hostname for SASL service-principal lookup (olcSaslHost).  Must
        match the hostname component of the ldap/ principal in the
        keytab, e.g. "porkchop.ts.matos.cc" for the principal
        ldap/porkchop.ts.matos.cc@REALM.  Leave empty to let slapd use
        the system hostname (gethostname).
      '';
    };

    saslAuthzRegexp = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [ ];
      description = ''
        olcAuthzRegexp entries mapping SASL/GSSAPI identities to LDAP
        DNs.  Each string is "<match-regex> <replace-dn>" exactly as
        accepted by ldapmodify.  The regex matches the SASL identity
        presented by Cyrus SASL — for GSSAPI/Kerberos this is
        "uid=<principal>,cn=<REALM>,cn=gssapi,cn=auth".  Example:
          "{0}uid=alberth,cn=[^,]*,cn=gssapi,cn=auth cn=admin,dc=example,dc=com"
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.ldapAdminPassword = {
      file  = cfg.adminPasswordFile;
      owner = "openldap";
    };

    age.secrets.ldapKdcPassword = {
      file  = cfg.kdcPasswordFile;
      owner = "openldap";
    };

    # slapd SASL/GSSAPI keytab — deployed with openldap ownership so the
    # daemon can read it; /etc/krb5.keytab is root-only and cannot be used.
    age.secrets.ldapSaslKeytab = lib.mkIf (cfg.saslKeytabFile != null) {
      file  = cfg.saslKeytabFile;
      owner = "openldap";
      mode  = "0600";
    };

    # Point slapd at its dedicated keytab via the environment.  This is
    # evaluated after agenix has written the secret, so the path is valid
    # by the time slapd starts.
    systemd.services.openldap = lib.mkIf (cfg.saslKeytabFile != null) {
      environment.KRB5_KTNAME = config.age.secrets.ldapSaslKeytab.path;
    };

    services.openldap = {
      enable        = true;
      # mutableConfig = true: NixOS only initialises slapd.d if it does not
      # already exist; it does NOT chmod the directory read-only on every
      # activation.  This is required so that ldapmodify -Y EXTERNAL can
      # persist changes (e.g. setting a hashed olcRootPW).  Without this the
      # backend returns error (80) on any modify because the slapd.d files
      # are unwritable.
      mutableConfig = true;
      # ldapi:/// is always included (needed for SASL EXTERNAL / rootpw
      # management).  When listenAddresses is non-empty it fully replaces
      # the default ldap://127.0.0.1/ entry to avoid double-binding port
      # 389 when the caller passes ldap://0.0.0.0/ (0.0.0.0 includes
      # 127.0.0.1, so having both causes errno=98 at startup).
      urlList = [ "ldapi:///" ] ++ (
        if cfg.listenAddresses != [ ]
        then cfg.listenAddresses
        else [ "ldap://127.0.0.1:${toString cfg.port}/" ]
      );

      settings = {
        attrs = {
          olcLogLevel = "stats";
          # SASL/GSSAPI — only included when the corresponding options are set.
          # On an existing slapd these must be applied via ldapmodify
          # (mutableConfig = true means Nix only initialises slapd.d once).
        } // lib.optionalAttrs (cfg.saslHost != "") {
          olcSaslHost = cfg.saslHost;
        } // lib.optionalAttrs (cfg.saslAuthzRegexp != [ ]) {
          olcAuthzRegexp = cfg.saslAuthzRegexp;
        } // lib.optionalAttrs (cfg.tlsCertFile != null) {
          olcTLSCertificateFile = cfg.tlsCertFile;
        } // lib.optionalAttrs (cfg.tlsKeyFile != null) {
          olcTLSCertificateKeyFile = cfg.tlsKeyFile;
        };

        children = {
          # Grant root (via Unix socket EXTERNAL auth) full access to cn=config.
          # Without this entry, ldapmodify -Y EXTERNAL on ldapi:/// gets
          # "Insufficient access (50)" when trying to modify the config DIT.
          "olcDatabase={0}config" = {
            attrs = {
              objectClass = "olcDatabaseConfig";
              olcDatabase = "{0}config";
              olcAccess = [
                "{0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage stop by * none stop"
              ];
            };
          };

          "cn=schema" = {
            includes = [
              "${pkgs.openldap}/etc/schema/core.ldif"
              "${pkgs.openldap}/etc/schema/cosine.ldif"
              "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
              "${pkgs.openldap}/etc/schema/nis.ldif"
              # Kerberos schema in cn=config LDIF format — bundled statically
              # (nixpkgs does not ship this; .schema format fails slapadd;
              # slaptest output has operational attrs that also fail slapadd)
              "${../kerberos.ldif}"
            ];
          };

          "olcDatabase={1}mdb" = {
            attrs = {
              objectClass  = [ "olcDatabaseConfig" "olcMdbConfig" ];
              olcDatabase  = "{1}mdb";
              olcDbDirectory = "/var/lib/openldap/data";
              olcSuffix    = cfg.baseDN;
              olcRootDN    = "cn=admin,${cfg.baseDN}";
              # Password is loaded at runtime via a slapd password file
              olcRootPW    = { path = config.age.secrets.ldapAdminPassword.path; };
              olcAccess    = [
                # Both KDC and kadmin service accounts need write access to
                # the Kerberos subtree.  Granting only cn=kdc causes kadmind
                # and kadmin.local to fail with "Unable to read Realm: No
                # such object" because cn=kadmin falls through to "by * none".
                ''to dn.subtree="cn=kerberos,${cfg.baseDN}" by dn="cn=kdc,${cfg.baseDN}" write by dn="cn=kadmin,${cfg.baseDN}" write by * none''
                ''to * by self write by users read by anonymous auth''
              ];
            };
          };
        };
      };
    };

    # Ensure LDAP data directory exists with correct ownership
    systemd.tmpfiles.rules = [
      "d /var/lib/openldap/data 0700 openldap openldap -"
    ];
  };
}
