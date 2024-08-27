{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    dbus.packages = [ pkgs.gcr ];
  };
}
