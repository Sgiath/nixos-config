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
    audiobookshelf.enable = true;
    dnd5etools.enable = true;
    foundryvtt.enable = true;
    home-assistant.enable = true;
    jitsi-meet.enable = true;
    matrix.enable = true;
    pi-hole.enable = true;
    searx.enable = true;
  };
}
