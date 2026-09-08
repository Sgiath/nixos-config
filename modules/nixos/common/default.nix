{ config, lib, ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./optimizations.nix
    ./secrets.nix
    ./security.nix
    ./udev.nix
    ./usb.nix
    ./users.nix
    ./yggdrasil.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    system = {
      stateVersion = "23.11";
    };

    home-manager.users.sgiath.sgiath = {
      enable = true;
      roles.terminal.enable = true;
    };
  };
}
