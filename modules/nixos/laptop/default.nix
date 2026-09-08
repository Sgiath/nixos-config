{ config, lib, ... }:
{
  options.sgiath.roles.laptop.enable = lib.mkEnableOption "notebook role";

  config = lib.mkIf config.sgiath.roles.laptop.enable {
    networking.networkmanager.enable = lib.mkForce true;

    environment.etc."resolv.conf".text = lib.mkForce ''
      nameserver 1.1.1.1
      nameserver 8.8.8.8
    '';
  };
}
