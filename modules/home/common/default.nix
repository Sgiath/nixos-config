{ lib, ... }:
{
  imports = [
    ./base.nix
    ./secrets.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";
}
