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
      configType = "hyprlang";
      xwayland.enable = true;
      package = null;
      portalPackage = null;

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        group.groupbar.font_size = 14;

        workspace = [
          "special:special, gapsout:30"
          "1,monitor:DP-1,default:true,persistent:true,defaultName:terminal"
          "2,monitor:DP-3,default:true,persistent:true,defaultName:personal"
          "3,monitor:DP-3,persistent:true,defaultName:CrazyEgg"
          "4,monitor:DP-3,persistent:true,defaultName:Remote"
          "5,monitor:DP-3,persistent:true,defaultName:"
          "6,monitor:DP-1,persistent:true,defaultName:"
          "7,monitor:DP-1,persistent:true,defaultName:"
          "8,monitor:DP-1,persistent:true,defaultName:firefox"
          "9,monitor:DP-3,persistent:true,defaultName:email"
          "10,monitor:DP-2,default:true,gapsin:0,gapsout:0,border:false,persistent:true,defaultName:comm"
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
