{ pkgs, ... }:

{
  xsession = {
    enable = true;

    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = ./xmonad/xmonad.hs;
      libFiles."Colors.hs" = ./xmonad/lib/Colors/Yoru.hs;
    };
  };

  services.dunst = {
    enable = true;
    iconTheme = {
      name = "Paper";
      package = pkgs.paper-icon-theme;
    };
  };
  services.flameshot.enable = true;
}
