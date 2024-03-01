{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {

    # system
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    };

    # home
    homeConfigurations = {
      sgiath = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
  };
}
