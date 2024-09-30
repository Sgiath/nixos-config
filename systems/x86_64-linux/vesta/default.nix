{
  imports = [ ./hardware.nix ];

  home-manager.users.sgiath = import (./../../../homes/x86_64-linux + "/sgiath@vesta");

  networking.hostName = "vesta";

  sgiath = {
    enable = true;
    server.enable = true;
  };

  services = {
    dnd5etools.enable = true;
    audiobookshelf.enable = true;
    pi-hole.enable = true;
    foundryvtt.enable = true;
    home-assistant.enable = true;
  };
}
