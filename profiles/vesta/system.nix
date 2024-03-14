{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix

    # bitcoin
    ../../system/bitcoin.nix
  ];

  networking.hostName = "vesta";

  boot.kernelPackages = pkgs.linuxPackages_zen;
}
