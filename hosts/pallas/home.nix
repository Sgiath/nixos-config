{
  imports = [
    # default values
    ../home.nix

    # audio
    ../../home-manager/audio.nix

    # GUI apps
    ../../home-manager/xmonad.nix
    ../../home-manager/polybar.nix
    ../../home-manager/rofi.nix
    ../../home-manager/wezterm.nix
    ../../home-manager/browser.nix
    ../../home-manager/email_client.nix

    # CrazyEgg
    ../../work/aws.nix
    ../../work/nginx.nix
  ];

  stylix = {
    fonts = {
      sizes = {
        applications = 12;
        terminal = 14;
      };
    };
  };
}
