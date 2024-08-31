{
  imports = [ ./hardware.nix ];

  networking.hostName = "vesta";

  sgiath = {
    enable = true;
    audio.enable = false;
    bluetooth.enable = false;
    docker.enable = true;
    gaming.enable = false;
    networking.localDNS.enable = false;
    printing.enable = false;
    razer.enable = false;
    wayland.enable = false;
  };
}
