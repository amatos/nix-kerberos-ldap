{ nix-secrets }:

{ config, lib, pkgs, ... }:

{
  imports = [
    ./ldap.nix
    ./kerberos.nix
  ];

  # Pass nix-secrets path into modules that need it
  _module.args.nix-secrets = nix-secrets;
}
