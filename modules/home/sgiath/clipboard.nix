{ pkgs, ... }:
{
  services.clipse.enable = true;
  home.packages = with pkgs; [
    wl-clipboard
    wl-clipboard-x11
  ];
  wayland.windowManager.hyprland.settings = {
    bind = [ "$mod, V, exec, ${pkgs.kitty}/bin/kitty --class clipse -e ${pkgs.clipse}/bin/clipse" ];
    windowrulev2 = [
      "float, class:(clipse)"
      "size 622 652, class:(clipse)"
      "stayfocused, class:(clipse)"
    ];
  };
}
