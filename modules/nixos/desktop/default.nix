{ config, lib, ... }:
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./printing.nix
    ./stylix.nix
    ./wayland.nix
  ];

  options.sgiath.roles.desktop.enable = lib.mkEnableOption "graphical workstation role";

  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home-manager.users.sgiath.sgiath.roles.desktop.enable = true;
  };
}
