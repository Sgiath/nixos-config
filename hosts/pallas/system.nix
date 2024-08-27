{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";

  graphical = {
    enable = true;
    gpu = "nvidia";
  };

  sgiath = {
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = false;
    printing.enable = true;
    razer.enable = true;
  };

  crazyegg.enable = true;
}
