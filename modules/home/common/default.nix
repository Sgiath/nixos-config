{ lib, ... }:
{
  imports = [
    ./base.nix
    ./secrets.nix
    ./stylix.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";
}
