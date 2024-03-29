{ pkgs, ... }:

{
  imports = [
    # default values
    ../home.nix

    # CrazyEgg
    ../../work/default.nix

    ../../home-manager/audio.nix
    ../../home-manager/gui.nix
    ../../home-manager/games.nix
    ../../home-manager/ollama.nix
  ];

  home.packages = [ pkgs.nitrogen pkgs.cinnamon.nemo-with-extensions ];

  stylix = {
    fonts = {
      sizes = {
        applications = 10;
        desktop = 10;
        popups = 10;
        terminal = 10;
      };
    };
  };
}
