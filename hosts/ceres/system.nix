{ pkgs, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix
    ./monitors.nix

    # modules
    ../../nixos/x11.nix
    ../../nixos/sound.nix
    ../../nixos/printing.nix
    ../../nixos/gaming.nix
    ../../nixos/bluetooth.nix

    # work
    ../../work/nginx.nix
  ];

  networking.hostName = "ceres";

  # AMD GPU
  services.xserver.videoDrivers = [ "amdgpu" ];
  systemd.tmpfiles.rules =
    [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];
  hardware.opengl = {
    extraPackages = with pkgs; [ rocmPackages.clr rocmPackages.clr.icd amdvlk ];
    extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
  };

  # temporary, move it out
  virtualisation.docker.enable = true;
}
