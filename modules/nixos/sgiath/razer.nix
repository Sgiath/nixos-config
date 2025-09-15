{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.razer = {
    enable = lib.mkEnableOption "Razer notebook";
  };

  config = lib.mkIf config.sgiath.razer.enable {
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
