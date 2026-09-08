{ config, lib, ... }:

{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    services = {
      printing.enable = true;

      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };
  };
}
