{ config, lib, ... }:

{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
