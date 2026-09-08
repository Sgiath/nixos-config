{
  imports = [
    ./hardware.nix
    ./disko.nix
    ./services.nix
  ];

  networking.hostName = "vesta";
  networking.wireguard.enable = false;

  sgiath = {
    enable = true;
    roles.server.enable = true;
  };

  virtualisation.docker.enable = true;
}
