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

    services.openldap = {
      enable    = true;
      urlList   = [
        "ldap://127.0.0.1:${toString cfg.port}/"
        "ldapi:///"   # required for SASL EXTERNAL (rootpw management)
      ];

      settings = {
        attrs = {
          olcLogLevel = "stats";
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
                # KDC service account gets write access to Kerberos subtree
                ''to dn.subtree="cn=kerberos,${cfg.baseDN}" by dn="cn=kdc,${cfg.baseDN}" write by * none''
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
