{
  config,
  lib,
  pkgs,
  userSettings,
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
    ];

    hardware.openrazer = {
      enable = true;
      users = [ userSettings.username ];
    };

    users.users.${userSettings.username}.extraGroups = [ "openrazer" ];
  };
}
