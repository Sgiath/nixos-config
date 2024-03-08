{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix

    # modules
    ../../system/x11.nix
    ../../system/sound.nix
  ];

  # printing
  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.openFirewall = true;

  # Enable bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Steam
  programs.steam = {
    enable = true;
  };

  # enable Cachix for gaming
  nix.settings = {
    substituters = [ "https://nix-gaming.cachix.org" ];
    trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
  };
}
