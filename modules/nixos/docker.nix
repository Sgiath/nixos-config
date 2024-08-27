{
  config,
  lib,
  userSettings,
  ...
}:
{
  options.sgiath.docker = {
    enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf config.sgiath.docker.enable {
    virtualisation.docker.enable = true;
    users.users.${userSettings.username}.extraGroups = [ "docker" ];
  };
}
