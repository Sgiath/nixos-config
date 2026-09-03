{
  config,
  pkgs,
  lib,
  ...
}:
let
  noctalia = lib.getExe config.programs.noctalia.package;
  sessionMenuCommand = "${noctalia} msg panel-toggle session";
  launcherCommand = "${noctalia} msg panel-toggle launcher";
in
{
  config = lib.mkIf config.programs.noctalia.enable {
    programs.noctalia = {
      systemd.enable = true;

      settings = {
        shell = {
          avatar_path = "/home/sgiath/Pictures/profile/cyborg_cowboy_head.jpg";
          time_format = "{:%H:%M:%S}";
          date_format = "%Y-%m-%d";
          launch_apps_as_systemd_services = true;

          launcher.pinned = [
            "chromium-browser"
            "google-chrome"
            "firefox"
          ];
        };

        location.address = "Ostrava, Czechia";
        weather.enabled = true;

        bar.main = {
          enabled = false;
          thickness = 47;
          capsule_thickness = 0.65;

          start = [
            "launcher"
            "active_window"
            "media"
          ];
          center = [ "workspaces" ];
          end = [
            "cpu"
            "temperature"
            "memory"
            "notifications"
            "battery"
            "volume"
            "clock"
            "tray"
            "control-center"
          ];

          monitor = {
            "DP-1".enabled = true;
            "DP-3".enabled = true;
            "eDP-1".enabled = true;
          };
        };

        widget = {
          workspaces = {
            occupied_color = "tertiary";
            labels_only_when_occupied = false;
            pill_scale = 0.75;
          };
          media.album_art_only = true;

          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
          };
          temperature = {
            type = "sysmon";
            stat = "cpu_temp";
          };
          memory = {
            type = "sysmon";
            stat = "ram_used";
          };

          clock.format = "{:%H:%M:%S %Y-%m-%d}";
        };

        dock = {
          enabled = true;
          icon_size = 60;
          active_monitor_only = false;
          monitors = [ "DP-1" ];
          auto_hide = true;
        };

        notification.monitors = [ "DP-1" ];
      };
    };

    systemd.user.services.noctalia.Service.Environment = "TERMINAL=${lib.getExe pkgs.kitty}";

    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + SHIFT + Q"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON sessionMenuCommand})")
          ];
        }
        {
          _args = [
            "SUPER + slash"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON launcherCommand})")
          ];
        }
      ];

      layer_rule = [
        {
          name = "noctalia";
          match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
          no_anim = true;
          ignore_alpha = 0.5;
          blur = true;
          blur_popups = true;
        }
      ];
    };
  };
}
