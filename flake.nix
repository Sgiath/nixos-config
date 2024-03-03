{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
    NvChad.url = "github:NvChad/nix";
  };

  outputs = { self, nixpkgs, home-manager, NvChad, stylix, ... }@inputs:
    let
      # ---- SYSTEM SETTINGS ---- #
      systemSettings = {
        system = "x86_64-linux";
        hostname = "nixos";
        profile = "desktop";
        timezone = "UTC";
        locale = "en_US.UTF-8";
      };

      # ---- USER SETTINGS ---- #
      userSettings = {
        username = "sgiath";
        email = "sgiath@sgiath.dev";
        dotfilesDir = "~/.dotfiles";
        wm = "xmonad";
      };


      pkgs = import nixpkgs {
        system = systemSettings.system;
        config.allowUnfree = true;
      };
    in {

    # system
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        modules = [ (./. + "/profiles" + ("/" + systemSettings.profile) + "/system.nix") ];
        specialArgs = {
          inherit systemSettings;
          inherit userSettings;
        };
      };
    };

    # home
    homeConfigurations = {
      ${userSettings.username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (./. + "/profiles" + ("/" + systemSettings.profile) + "/home.nix")
          stylix.homeManagerModules.stylix
          NvChad.homeManagerModules.default
        ];
        extraSpecialArgs = {
          inherit userSettings;
        };
      };
    };
  };
}
