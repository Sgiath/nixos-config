{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  graphical = {
    enable = true;
    gpu = "amd";
  };

  sgiath = {
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = true;
    printing.enable = true;
    razer.enable = false;
  };

  crazyegg.enable = true;
}
