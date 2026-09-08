{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.hardware.razer.enable {
    environment.systemPackages = with pkgs; [
      razergenie
      openrazer-daemon
      alsa-tools
    ];

    hardware.openrazer = {
      enable = true;
      users = [ "sgiath" ];
    };

    users.users.sgiath.extraGroups = [ "openrazer" ];
  };
}
