{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "vesta";
  networking.wireguard.enable = false;

  sgiath = {
    enable = true;
    docker.enable = true;
    server.enable = true;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "minio-2025-10-15T17-29-55Z"
  ];

  services = {
    buzz-relay = {
      enable = true;
      ownerPubkey = "0000002855ad7906a7568bf4d971d82056994aa67af3cf0048a825415ac90672"
    };
    i2p.enable = true;

    audiobookshelf.enable = true;
    matrix.enable = true;
    pi-hole.enable = true;
    searx.enable = true;
    transmission.enable = true;
    jellyfin.enable = true;
    nostr-rs-relay.enable = true;
    xmpp.enable = true;

    foundryvtt.enable = true;
    dnd5etools.enable = true;
    factorio.enable = false;

    open-webui.enable = false;
    mollysocket.enable = true;
    ntfy-sh.enable = true;
    monitoring.enable = false;

    hermes-agent.enable = true;

    # proxies
    nas-proxy.enable = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    ai-proxy.enable = false;
    eve-proxy.enable = false;
  };
}
