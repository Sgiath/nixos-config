{
  config,
  lib,
  ...
}:
{
  options.sgiath.docker = {
    enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf config.sgiath.docker.enable {
    virtualisation = {
      docker = {
        enable = true;
        storageDriver = "btrfs";
      };

      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    users.users.sgiath.extraGroups = [ "docker" ];
  };
}
