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
      # webcord
      telegram-desktop
      signal-desktop
      # simplex-chat-desktop
      gajim
      weechat
      cinny-desktop
      fluffychat

      # nostr CLI
      pkgs.${namespace}.nak

      # buzz
      pkgs.${namespace}.buzz
    ];

    programs = {
      element-desktop = {
        enable = true;
        settings = {
          default_server_config = {
            "m.homeserver" = {
              base_url = "https://matrix.sgiath.dev";
              server_name = "sgiath.dev";
            };
          };

          features = {
            feature_latex_maths = true;
            feature_pinning = true;
            feature_dm_verification = true;
            feature_location_share_live = true;
            feature_video_rooms = true;
            feature_element_call_video_rooms = true;
            feature_group_calls = true;
            feature_new_room_list = true;
          };

          disable_custom_urls = false;
          disable_login_language_selector = false;
          force_verification = true;

          default_theme = "dark";
          brand = "matrix";
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd(${builtins.toJSON (lib.getExe pkgs.slack)})
                hl.exec_cmd(${builtins.toJSON (lib.getExe pkgs.signal-desktop)})
                hl.exec_cmd(${builtins.toJSON (lib.getExe pkgs.cinny-desktop)})
              end
            '')
          ];
        }
      ];
      window_rule =
        map
          (class: {
            match.class = class;
            workspace = "10 silent";
            no_initial_focus = true;
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
    };
  };
}
