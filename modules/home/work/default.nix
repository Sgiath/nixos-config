{ lib, ... }:
{
  imports = [
    ./aws.nix
    ./crazyegg.nix
    ./remote.nix
  ];

  options.sgiath.work = {
    crazyegg.enable = lib.mkEnableOption "CrazyEgg home manager";
    remote.enable = lib.mkEnableOption "Remote home manager";
  };
}
