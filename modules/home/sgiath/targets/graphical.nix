{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  terminalCommand = lib.getExe pkgs.kitty;
in
{
  options.sgiath.targets.graphical = lib.mkEnableOption "graphical target";

  config = lib.mkIf (config.sgiath.targets.graphical) {
    home.packages = with pkgs; [
      xterm
      vlc
      kdePackages.okular
      libwacom
      appimage-run
      pkgs.${namespace}.orca
    ];

    wayland.windowManager.hyprland.settings = {
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd(${builtins.toJSON terminalCommand})
              end
            '')
          ];
        }
      ];
      bind = [
        {
          _args = [
            "SUPER + Return"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON terminalCommand})")
          ];
        }
      ];
      window_rule = [
        {
          match.class = "alacritty";
          workspace = "1";
        }
        {
          match.class = "kitty";
          workspace = "1";
        }
        {
          match.class = "wezterm";
          workspace = "1";
        }
        {
          match.class = "ghostty";
          workspace = "1";
        }
      ];
    };

    services = {
      udiskie.enable = true;
    };

    programs = {
      # hyprland
      hyprland.enable = true;
      noctalia-shell.enable = true;
      waybar.enable = false;

      # terminals
      alacritty.enable = false;
      kitty = {
        enable = true;
        settings.auto_reload_config = -1;
      };
      wezterm.enable = false;
      ghostty.enable = false;

      # utils
      voxtype.enable = true;
      pandoc.enable = true;
      vscode.enable = false;
      obs-studio.enable = true;

      obsidian = {
        enable = true;
        cli.enable = true;
      };
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      bitcoin.enable = true;
      comm.enable = true;
      editors.enable = true;
      email_client.enable = true;
      web_browsers.enable = true;
    };

    xdg.desktopEntries."vue" = {
      name = "Visual Unederstanding Environment";
      genericName = "VUE";
      exec = "${lib.getExe pkgs.vue}";
    };
  };
}
