{ lib, ... }:
{
  imports = [
    ./ai.nix
    ./eve.nix
    ./nas.nix
    ./sgiath-dev.nix
    ./sinai-camp.nix
  ];

  options.sgiath.sites = {
    sgiath-dev.enable = lib.mkEnableOption "sgiath.dev proxy";
    sinai-camp.enable = lib.mkEnableOption "sinai.camp proxy";
    nas.enable = lib.mkEnableOption "NAS proxy";
    eve.enable = lib.mkEnableOption "EVE proxy";
    ai.enable = lib.mkEnableOption "OpenCode/AoE proxy";
  };
}
