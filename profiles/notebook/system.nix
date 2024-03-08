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

  # Nvidia and AMD GPUs
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;
      amdgpuBusId = "PCI:101:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  environment.systemPackages = [ pkgs.lshw ];

  # Enable bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
