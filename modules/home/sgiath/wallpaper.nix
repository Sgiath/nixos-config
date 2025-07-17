{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      plugins = [
        pkgs.hyprlandPlugins.hyprwinwrap
      ];

      settings = {
        # exec-once = [
        #   "${pkgs.firefox}/bin/firefox --new-window 'https://eyes.nasa.gov/apps/solar-system/#/home' --name='nasa' --kiosk"
        # ];

        plugin.hyprwinwrap.class = "nasa";
        
        windowrulev2 = [
          "fullscreenstate 0 0, class:(nasa)"
          "workspace special:nasa silent, class:(nasa)"
          # "noinitialfocus, class:(nasa)"
        ];
      };
    };

    services = {
      hyprpaper = {
        enable = true;
        settings = lib.mkForce {
          preload = [ "${./wallpapers/transhumanism.png}" ];
          wallpaper = [
            "DP-1,contain:${./wallpapers/transhumanism.png}"
            "DP-3,contain:${./wallpapers/transhumanism.png}"
            "DP-2,contain:${./wallpapers/transhumanism.png}"
          ];
        };
      };
    };
  };
}
