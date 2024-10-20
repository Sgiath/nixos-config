{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "vesta";

  sgiath = {
    enable = true;
    docker.enable = true;
    server.enable = true;
  };

  services = {
    dnd5etools.enable = true;
    audiobookshelf.enable = true;
    foundryvtt.enable = true;
    home-assistant.enable = true;
    jitsi-meet.enable = true;
    matrix.enable = false;
    monitoring.enable = true;
    nas-proxy.enable = true;
    osm.proxy = false;
    pi-hole.enable = true;
    searx.enable = true;
    sgiath-dev.proxy = true;
    wordpress.proxy = false;
    xmpp.enable = false;
  };
}
