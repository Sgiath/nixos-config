{ lib, ... }:
{
  imports = [
    ./role.nix
    ./chromium.nix
    ./clipboard.nix
    ./hyprland.nix
    ./noctalia.nix
    ./voxtype.nix
    ./yazi.nix
  ];

  options.sgiath.roles.desktop.enable = lib.mkEnableOption "desktop role";
}
