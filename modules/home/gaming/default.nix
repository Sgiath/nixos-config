{ lib, ... }:
{
  imports = [ ./role.nix ];

  options.sgiath.roles.gaming.enable = lib.mkEnableOption "gaming role";
}
