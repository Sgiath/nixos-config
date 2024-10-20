{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "hygiea";

  sgiath = {
    enable = true;
    boot = "legacy";
    docker.enable = false;
    server.enable = true;
  };

  services = {
    dnd5etools.enable = false;
    audiobookshelf.enable = false;
    foundryvtt.enable = false;
    home-assistant.enable = false;
    jitsi-meet.enable = false;
    matrix.enable = false;
    monitoring.enable = false;
    nas-proxy.enable = false;
    osm.proxy = false;
    pi-hole.enable = false;
    searx.enable = false;
    sgiath-dev.proxy = false;
    wordpress.proxy = false;
    xmpp.enable = false;
  };
}
