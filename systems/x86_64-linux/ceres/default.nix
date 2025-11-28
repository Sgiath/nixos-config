{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  sgiath = {
    enable = true;
    gpu = "amd";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = true;
    printing.enable = true;
    razer.enable = false;
    wayland.enable = true;
  };

  crazyegg.enable = true;

  services = {
    ollama.enable = false;
  };

  programs = {
    gamescope.enable = true;
    gamemode.enable = true;

    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs = pkgs: [ pkgs.gamemode ];
      };
      remotePlay.openFirewall = true;
      protontricks.enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
  };
}
