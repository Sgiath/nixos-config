{ config, ... }:

{
  services.polybar = {
    enable = true;
    script = ''
      polybar &
    '';
    config = {
      "global/wm" = {
        margin-top = 0;
        margin-bottom = 0;
      };

      "bar/main" = {
        # monitor = "DP-1";
        width = "100%";
        height = 22;
        radius = 0;
        bottom = false;
        modules-left = "ewmh xwindow";
        modules-right = "date";

        background = "#0c0e0f";
        foreground = "#edeff0";

        line-size = 2;
        line-color = "#df5b61";

        border-color = "#2c2e2f";

        padding-left = 0;
        padding-right = 1;

        enable-ipc = true;

        # Font
        font-0 = "RobotoMono Nerd Font:style=Bold:size=9;2";
      };

      "module/ewmh" = {
        type = "internal/xworkspaces";
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title%";
      };

      "module/date" = {
        type = "internal/date";
        interval = 5;
        date = "%F";
        date-alt = "%F";
        time = "%H%M";
        time-alt = "%H%M";
        label = "%date% %time%";
      };
    };
  };
}
