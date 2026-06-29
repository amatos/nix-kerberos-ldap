{ config, lib, pkgs, nix-secrets, ... }:

let
  cfg = config.services.kerberosLdap.kerberos;
  ldapCfg = config.services.kerberosLdap.ldap;
in {
  options.services.kerberosLdap.kerberos = {
    enable = lib.mkEnableOption "MIT Kerberos KDC with LDAP backend";

    realm = lib.mkOption {
      type    = lib.types.str;
      example = "EXAMPLE.COM";
      description = "Kerberos realm name (typically the domain in uppercase).";
    };

    ldapUri = lib.mkOption {
      type    = lib.types.str;
      default = "ldap://127.0.0.1";
      description = "URI of the LDAP server to use as the KDC database backend.";
    };

    ldapBaseDN = lib.mkOption {
      type    = lib.types.str;
      description = "LDAP base DN for Kerberos data (defaults to ldap.baseDN if set).";
      default = ldapCfg.baseDN or "";
    };

    masterKeyFile = lib.mkOption {
      type        = lib.types.path;
      description = "Path to the age-encrypted Kerberos master key file (from nix-secrets).";
      default     = "${nix-secrets}/krb5-master-key.age";
    };

    kdcLdapPasswordFile = lib.mkOption {
      type        = lib.types.path;
      description = "Path to the age-encrypted KDC LDAP service account password (from nix-secrets).";
      default     = "${nix-secrets}/ldap-kdc-password.age";
    };

    krb5Package = lib.mkOption {
      type        = lib.types.package;
      default     = pkgs.krb5;
      description = "krb5 package providing krb5kdc and kadmind. Must be built with LDAP support (withLdap = true).";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.krb5MasterKey = {
      file  = cfg.masterKeyFile;
      owner = "root";
      mode  = "0400";
    };

    age.secrets.kdcLdapPassword = {
      file  = cfg.kdcLdapPasswordFile;
      owner = "root";
      mode  = "0400";
    };

    environment.etc."krb5.conf".text = ''
      [libdefaults]
        default_realm = ${cfg.realm}
        dns_lookup_realm = false
        dns_lookup_kdc = false

      [realms]
        ${cfg.realm} = {
          kdc = localhost
          admin_server = localhost
          database_module = openldap
        }

      [domain_realm]
        .${lib.toLower cfg.realm} = ${cfg.realm}
        ${lib.toLower cfg.realm} = ${cfg.realm}

      [dbmodules]
        openldap = {
          db_library = kldap
          ldap_kerberos_container_dn = cn=kerberos,${cfg.ldapBaseDN}
          ldap_kdc_dn = cn=kdc,${cfg.ldapBaseDN}
          ldap_kadmind_dn = cn=kadmin,${cfg.ldapBaseDN}
          ldap_service_password_file = ${config.age.secrets.kdcLdapPassword.path}
          ldap_servers = ${cfg.ldapUri}
        }

      [logging]
        kdc          = FILE:/var/log/krb5/kdc.log
        admin_server = FILE:/var/log/krb5/kadmin.log
    '';

    systemd.services.kdc = {
      description = "MIT Kerberos KDC";
      after       = [ "network.target" "openldap.service" ];
      requires    = [ "openldap.service" ];
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart     = "${cfg.krb5Package}/bin/krb5kdc -n";
        Restart       = "on-failure";
        # Master key stash file must exist before starting;
        # run `kdb5_ldap_util stashsrvpw` and `kdb5_util create` during provisioning.
        StateDirectory = "krb5kdc";
        LogsDirectory  = "krb5";
      };
    };

    systemd.services.kadmind = {
      description = "MIT Kerberos Admin Server";
      after       = [ "kdc.service" ];
      requires    = [ "kdc.service" ];
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.krb5Package}/bin/kadmind -nofork";
        Restart   = "on-failure";
      };
    };

    environment.systemPackages = [ cfg.krb5Package ];
  };
}
