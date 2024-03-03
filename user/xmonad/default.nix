{ config, ... }:

{
  xsession = {
    enable = true;

    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = ./xmonad.hs;
      libFiles = {
        "Colors.hs" = ./lib/Colors/Yoru.hs;
      };
    };
  };

  services.flameshot.enable = true;
}
