{ outputs, ... }:
{
  imports = [
    ./hardware.nix
    outputs.nixosModules
  ];

  networking.hostName = "vesta";

  sgiath = {
    amd-gpu.enable = false;
    nvidia-gpu.enable = false;
    audio.enable = false;
    bitcoin.enable = true;
    bluetooth.enable = false;
    docker.enable = true;
    gaming.enable = false;
    networking.localDNS.enable = false;
    printing.enable = false;
    razer.enable = false;
    wayland.enable = false;
  };
}
