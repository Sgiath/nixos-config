{
  config,
  lib,
  pkgs,
  ...
}:
let
  font = {
    package = pkgs.nerd-fonts.roboto-mono;
    name = "RobotoMono Nerd Font Mono";
  };
in
{
  config = lib.mkIf config.sgiath.enable {
    home.pointerCursor.enable = true;

    stylix = {
      enable = true;
      enableReleaseChecks = false;

      polarity = "dark";
      base16Scheme = ./yoru.yaml;

      cursor = {
        package = pkgs.nordzy-cursor-theme;
        name = "Nordzy-cursors";
        size = 24;
      };

      fonts = {
        monospace = font;
        serif = font;
        sansSerif = font;
        emoji = {
          name = "Noto Color Emoji";
          package = pkgs.noto-fonts-emoji-blob-bin;
        };
      };
    };
  };
}
