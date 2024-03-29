{ pkgs, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix

    # bitcoin
    ../../nixos/bitcoin.nix
  ];

  networking.hostName = "vesta";

  boot.kernelPackages = pkgs.linuxPackages_zen;
}
