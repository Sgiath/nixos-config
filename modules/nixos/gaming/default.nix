{ config, lib, ... }:
{
  imports = [ ./role.nix ];

  options.sgiath.roles.gaming.enable = lib.mkEnableOption "gaming role";

  config = lib.mkIf config.sgiath.roles.gaming.enable {
    home-manager.users.sgiath.sgiath.roles.gaming.enable = true;
  };
}
