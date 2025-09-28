{ lib, ... }:
{
  imports = [ ./hardware.nix ];

  networking = {
    hostName = "pallas";
    networkmanager.enable = lib.mkForce true;
  };

  environment.etc."resolv.conf".text = lib.mkForce ''
    nameserver 1.1.1.1
    nameserver 8.8.8.8
  '';

  sgiath = {
    enable = true;
    gpu = "nvidia";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = false;
    printing.enable = true;
    razer.enable = true;
    wayland.enable = true;
  };

  services = { };

  crazyegg.enable = true;
}
