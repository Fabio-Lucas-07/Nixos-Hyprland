{
  description = "Configuracao NixOS com Niri, Noctalia, Home Manager e Lanzaboote";

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

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs"; # this line is optional, prevents downloading two versions of nixpkgs but disables cache
    };
  };

  outputs = { self, nixpkgs, home-manager, lanzaboote, noctalia, ... }@inputs: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          home-manager.nixosModules.home-manager
          lanzaboote.nixosModules.lanzaboote
          {
            nixpkgs.overlays = [
              (final: prev: {
                noctalia-shell = noctalia.packages.${prev.system}.default;
                noctalia = noctalia.packages.${prev.system}.default;
              })
            ];
          }
        ];
      };
    };
  };
}
