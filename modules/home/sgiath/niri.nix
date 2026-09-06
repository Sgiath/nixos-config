{
  config,
  lib,
  pkgs,
  ...
}:
let
  terminal = lib.getExe pkgs.kitty;
  noctalia = lib.getExe config.programs.noctalia.package;
  colors = config.lib.stylix.colors.withHashtag;
in
{
  config = lib.mkIf config.wayland.windowManager.niri.enable {
    wayland.windowManager.niri = {
      package = pkgs.niri;
      # NixOS owns niri-session's units and desktop portals.
      systemd.enable = false;
      portalPackage = null;
      xwaylandSatellitePackage = pkgs.xwayland-satellite;

      settings = {
        input = {
          keyboard = {
            xkb.layout = "us";
            numlock = { };
            repeat-delay = 250;
            repeat-rate = 35;
          };
          touchpad = {
            natural-scroll = { };
            dwt = { };
            click-method = "clickfinger";
            scroll-factor = 0.5;
          };
          tablet.map-to-focused-output = { };
          focus-follows-mouse._props.max-scroll-amount = "0%";
        };

        cursor = {
          xcursor-theme = config.stylix.cursor.name;
          xcursor-size = config.stylix.cursor.size;
        };

        layout = {
          gaps = 10;
          background-color = colors.base00;
          default-column-width.proportion = 0.5;
          focus-ring = {
            width = 1;
            active-color = colors.base05;
            inactive-color = colors.base02;
          };
          border.off = { };
        };
        animations.off = { };
        prefer-no-csd = { };
        screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
        spawn-at-startup = [ terminal ];

        _children = [
          {
            output = {
              _args = [ "DP-1" ];
              mode = "5120x1440@120";
              position._props = {
                x = 0;
                y = 2560;
              };
              scale = 1;
            };
          }
          {
            output = {
              _args = [ "DP-3" ];
              mode = "3440x1440@165";
              position._props = {
                x = 0;
                y = 1120;
              };
              scale = 1;
            };
          }
          {
            output = {
              _args = [ "DP-2" ];
              mode = "2560x1440@165";
              position._props = {
                x = 3440;
                y = 0;
              };
              scale = 1;
              transform = "90";
            };
          }
          {
            output = {
              _args = [ "eDP-1" ];
              mode = "2560x1600@240";
              position._props = {
                x = 0;
                y = 0;
              };
              scale = 1;
            };
          }
          {
            window-rule = {
              geometry-corner-radius = 8;
              clip-to-geometry = true;
            };
          }
          {
            window-rule = {
              match._props.app-id = "^clipse$";
              open-floating = true;
              default-column-width.fixed = 622;
              default-window-height.fixed = 652;
            };
          }
        ];

        binds = {
          "Mod+Return".spawn = [ terminal ];
          "Mod+Slash".spawn = [
            noctalia
            "msg"
            "panel-toggle"
            "launcher"
          ];
          "Mod+Shift+Q".spawn = [
            noctalia
            "msg"
            "panel-toggle"
            "session"
          ];
          "Mod+E".spawn = [
            terminal
            "--class"
            "files"
            "-e"
            (lib.getExe pkgs.superfile)
          ];
          "Mod+V".spawn = [
            terminal
            "--class"
            "clipse"
            "-e"
            (lib.getExe pkgs.clipse)
          ];
          "Mod+Shift+C".close-window = { };
          "Mod+F".toggle-window-floating = { };
          "Mod+Shift+Space".fullscreen-window = { };
          "Mod+H".focus-column-left = { };
          "Mod+J".focus-window-down = { };
          "Mod+K".focus-window-up = { };
          "Mod+L".focus-column-right = { };
          "Mod+Shift+H".move-column-left = { };
          "Mod+Shift+J".move-window-down = { };
          "Mod+Shift+K".move-window-up = { };
          "Mod+Shift+L".move-column-right = { };
          "Mod+Left".focus-workspace-up = { };
          "Mod+Right".focus-workspace-down = { };
          "Mod+Ctrl+H".focus-monitor-left = { };
          "Mod+Ctrl+J".focus-monitor-down = { };
          "Mod+Ctrl+K".focus-monitor-up = { };
          "Mod+Ctrl+L".focus-monitor-right = { };
          "Mod+Ctrl+Shift+H".move-column-to-monitor-left = { };
          "Mod+Ctrl+Shift+J".move-column-to-monitor-down = { };
          "Mod+Ctrl+Shift+K".move-column-to-monitor-up = { };
          "Mod+Ctrl+Shift+L".move-column-to-monitor-right = { };
          "Mod+O" = {
            _props.repeat = false;
            toggle-overview = { };
          };
          "Mod+Shift+Slash".show-hotkey-overlay = { };
          "Mod+R".switch-preset-column-width = { };
          "Mod+Shift+R".switch-preset-window-height = { };
          "Mod+Minus".set-column-width = "-10%";
          "Mod+Equal".set-column-width = "+10%";
          "Mod+Shift+Minus".set-window-height = "-10%";
          "Mod+Shift+Equal".set-window-height = "+10%";
          "Mod+C".center-column = { };
          "Mod+M".maximize-column = { };
          "Mod+BracketLeft".consume-or-expel-window-left = { };
          "Mod+BracketRight".consume-or-expel-window-right = { };
          "Mod+S".screenshot = { };
          "Mod+Shift+S".screenshot-screen = { };
          "Mod+Ctrl+Shift+Q" = {
            _props = {
              allow-inhibiting = false;
              repeat = false;
            };
            quit = { };
          };
        }
        // builtins.listToAttrs (
          lib.concatMap (
            number:
            let
              key = if number == 10 then "0" else toString number;
            in
            [
              {
                name = "Mod+${key}";
                value.focus-workspace = number;
              }
              {
                name = "Mod+Shift+${key}";
                value.move-window-to-workspace = number;
              }
            ]
          ) (lib.range 1 10)
        );
      };
    };
  };
}
