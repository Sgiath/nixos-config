{ lib, ... }:
{
  imports = [
    ./nginx.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}
