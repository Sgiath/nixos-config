{ pkgs, lib, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";

  environment.systemPackages = with pkgs; [ wpa_supplicant_gui ];
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
