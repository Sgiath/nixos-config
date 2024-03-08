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
    ../../system/printing.nix
    ../../system/gaming.nix
  ];

  # AMD GPU
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

}
