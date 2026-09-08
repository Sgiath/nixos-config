{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";

  sgiath = {
    enable = true;

    hardware = {
      gpu = "nvidia";
      razer.enable = true;
    };

    roles = {
      desktop.enable = true;
      laptop.enable = true;
    };
  };

  virtualisation.docker.enable = true;
}
