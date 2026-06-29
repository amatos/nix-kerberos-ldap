{
  description = "NixOS flake providing a Kerberos KDC with an OpenLDAP backing store";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-secrets = {
      url = "github:amatos/nix-secrets";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ragenix,
      nix-secrets,
      ...
    }:
    {
      nixosModules = {
        default = import ./modules/default.nix { inherit nix-secrets; };
        ldap = import ./modules/ldap.nix;
        kerberos = import ./modules/kerberos.nix;
      };
    };
}
