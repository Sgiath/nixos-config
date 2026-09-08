{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  options.sgiath.comm = {
    enable = lib.mkEnableOption "communication apps";
  };

  config = lib.mkIf (config.sgiath.comm.enable) {
    home.packages = with pkgs; [
      slack
      telegram-desktop
      signal-desktop
      simplex-chat-desktop
      gajim
      cinny-desktop
      fluffychat
    ];

    # Start on login as part of the graphical session.
    systemd.user.services = {
      slack = {
        Unit = {
          Description = "Slack";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.slack;
          Slice = "app.slice";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      signal-desktop = {
        Unit = {
          Description = "Signal";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.signal-desktop;
          Slice = "app.slice";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      cinny-desktop = {
        Unit = {
          Description = "Cinny";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.cinny-desktop;
          Slice = "app.slice";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    wayland.windowManager.hyprland = {
      # workspace 10 is dedicated to communication apps, kept as one tab group
      settings.window_rule =
        map
          (class: {
            match.class = class;
            workspace = "10 silent";
            no_initial_focus = true;
            group = "set";
          })
          [
            "slack"
            "WebCord"
            "signal"
            "org.telegram.desktop"
            "Hexchat"
            "fluffychat"
            "Element"
            "cinny"
          ];

      # Hyprland only auto-groups into the focused window's group, so windows
      # opened silently on workspace 10 each become their own single-window
      # group. Merge every tiled window that lands there into the existing one.
      extraConfig = ''
        hl.on("window.open", function(window)
          local ws = window.workspace
          if not ws or ws.id ~= 10 or window.floating then
            return
          end
          for _, group in ipairs(ws:get_groups()) do
            if group ~= window.group then
              group:add(window)
              return
            end
          end
        end)
      '';
    };
  };
}
