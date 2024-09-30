{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    services = {
      gvfs.enable = true;
      udisks2.enable = true;
      dbus.packages = [ pkgs.gcr ];
    };
  };
}
