{
  description = "Configuracao NixOS com Hyprland, Home Manager e Lanzaboote";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, lanzaboote, ... }@inputs:
    let
      hostDirs = builtins.readDir ./hosts;
      hostNames = builtins.filter (name: hostDirs.${name} == "directory") (builtins.attrNames hostDirs);

      mkHost = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          (./hosts + "/${name}")
          ./configuration.nix
          home-manager.nixosModules.home-manager
          lanzaboote.nixosModules.lanzaboote
          { networking.hostName = name; }
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hostNames mkHost;
    };
}
