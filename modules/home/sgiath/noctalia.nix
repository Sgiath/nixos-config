{
  config,
  pkgs,
  lib,
  ...
}:
let
  sessionMenuCommand = "${lib.getExe pkgs.noctalia-shell} ipc call sessionMenu toggle";
  launcherCommand = "${lib.getExe pkgs.noctalia-shell} ipc call launcher toggle";
in
{
  config = lib.mkIf config.programs.noctalia-shell.enable {
    home.packages = with pkgs; [
      grim
      imagemagick
      wl-clipboard
      satty
      swappy
    ];

    programs.noctalia-shell = {
      settings = {
        bar = {
          density = "spacious";
          monitors = [
            "DP-1"
            "DP-3"
            "eDP-1"
          ];
          widgets = {
            left = [
              { id = "Launcher"; }
              { id = "ActiveWindow"; }
              { id = "MediaMini"; }
            ];
            center = [
              {
                id = "Workspace";
                occupiedColor = "tertiary";
                showLabelsOnlyWhenOccupied = false;
                pillSize = 0.75;
              }
            ];
            right = [
              { id = "SystemMonitor"; }
              { id = "NotificationHistory"; }
              { id = "Battery"; }
              { id = "Volume"; }
              { id = "Clock"; }
              { id = "Tray"; }
              { id = "ControlCenter"; }
            ];
          };
        };

        general = {
          avatarImage = "/home/sgiath/Pictures/profile/cyborg_cowboy_head.jpg";
          clockFormat = "HH:mm:ss yyyy-MM-dd";
        };

        location = {
          monthBeforeDay = true;
          name = "Ostrava, Czechia";
        };

        appLauncher = {
          pinnedApps = [
            "chromium-browser"
            "google-chrome"
            "firefox"
          ];
          terminalCommand = "${lib.getExe pkgs.kitty} -e";
        };

        dock = {
          size = 2;
          onlySameOutput = false;
          monitors = [ "DP-1" ];
        };

        notifications = {
          monitors = [ "DP-1" ];
        };
      };
    };

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
          match.namespace = "noctalia-background-.*$";
          ignore_alpha = 0.5;
          blur = true;
          blur_popups = true;
        }
      ];
    };

    systemd.user.services.noctalia-shell = {
      Unit = {
        Description = "Noctalia shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe pkgs.noctalia-shell}";
        Restart = "on-failure";
        RestartSec = 2;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
