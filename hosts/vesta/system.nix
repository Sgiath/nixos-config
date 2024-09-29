{
  imports = [ ./hardware.nix ];

  home-manager.users.sgiath = import ./home.nix;

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
