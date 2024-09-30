{
  imports = [ ./hardware.nix ];

  home-manager.users.sgiath = import (./../../../homes/x86_64-linux + "/sgiath@pallas");

  networking.hostName = "pallas";

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

  crazyegg.enable = true;
}
