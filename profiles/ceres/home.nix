{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # audio
    ../../user/audio.nix

    # GUI apps
    ../../user/xmonad/default.nix
    ../../user/polybar.nix
    ../../user/rofi.nix
    ../../user/wezterm.nix
    ../../user/browser.nix
    ../../user/email_client.nix
  ];

  stylix = {
    fonts = {
      sizes = {
        applications = 10;
        terminal = 10;
      };
    };
  };
}
