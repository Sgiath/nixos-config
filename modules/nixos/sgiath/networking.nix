{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    networking = {
      networkmanager.enable = false;
      resolvconf.enable = lib.mkForce false;
      dhcpcd.extraConfig = "nohook resolv.conf";
      firewall.enable = false;
    };
    environment.etc."resolv.conf".text = ''
      search sgiath.dev

      nameserver 192.168.1.2
      nameserver 192.168.1.1
      nameserver 1.1.1.1
      nameserver 8.8.8.8
    '';

    users.users.sgiath.extraGroups = [ "networkmanager" ];
  };
}
