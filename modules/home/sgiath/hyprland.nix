{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland/color.nix
    ./hyprland/general.nix
    ./hyprland/keybindings.nix
    ./hyprland/layout.nix
    ./hyprland/looks.nix
    ./hyprland/monitors.nix
    ./hyprland/rules.nix
    ./hyprland/screenshot.nix
  ];

  options.programs.hyprland = {
    enable = lib.mkEnableOption "hyprland";
  };

  config = lib.mkIf config.programs.hyprland.enable {
    # home.packages = [ ];

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      xwayland.enable = true;
      package = null;
      portalPackage = null;

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        config.group.groupbar.font_size = 14;

        workspace_rule = [
          {
            workspace = "special:special";
            gaps_out = 30;
          }
          {
            workspace = "1";
            monitor = "DP-1";
            default = true;
            persistent = true;
            default_name = "terminal";
          }
          {
            workspace = "2";
            monitor = "DP-3";
            default = true;
            persistent = true;
            default_name = "personal";
          }
          {
            workspace = "3";
            monitor = "DP-3";
            persistent = true;
            default_name = "CrazyEgg";
          }
          {
            workspace = "4";
            monitor = "DP-3";
            persistent = true;
            default_name = "Remote";
          }
          {
            workspace = "5";
            monitor = "DP-3";
            persistent = true;
          }
          {
            workspace = "6";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "7";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "8";
            monitor = "DP-1";
            persistent = true;
            default_name = "firefox";
          }
          {
            workspace = "9";
            monitor = "DP-3";
            persistent = true;
            default_name = "email";
          }
          {
            workspace = "10";
            monitor = "DP-2";
            default = true;
            gaps_in = 0;
            gaps_out = 0;
            no_border = true;
            persistent = true;
            default_name = "comm";
          }
        ];
      };
    };
    stylix.targets = {
      hyprland.enable = false;
      fuzzel.enable = false;
    };

    gtk = pkgs.lib.mkForce {
      enable = true;
      gtk4.theme = null;
      theme = {
        package = pkgs.sgiath.nordic-gtk-theme;
        name = "Nordic";
      };
      cursorTheme = {
        package = pkgs.nordzy-cursor-theme;
        name = "Nordzy-cursors";
        size = 24;
      };
      iconTheme = {
        package = pkgs.nordzy-icon-theme;
        name = "Nordzy";
      };
    };

    programs.wofi = {
      enable = false;
      settings = {
        mode = "drun";
        prompt = "";
        insensitive = true;
      };
    };

    services = {
      mako.enable = true;
      hyprpolkitagent.enable = true;
    };
  };
}
