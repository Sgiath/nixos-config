{ lib, ... }:
{
  imports = [ ./nginx.nix ];

  options.crazyegg = {
    enable = lib.mkEnableOption "CrazyEgg module";
  };
}
