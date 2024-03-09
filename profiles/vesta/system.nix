{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;
}
