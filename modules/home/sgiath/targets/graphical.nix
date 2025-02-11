{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.targets.graphical = lib.mkEnableOption "graphical target";

  config = lib.mkIf (config.sgiath.targets.graphical) {
    home.packages = with pkgs; [
      nemo-with-extensions
      nemo-fileroller

      # utils
      obsidian
      gimp
      vlc
      okular
      plex-media-player
      texliveMedium
      libwacom
      # varia

      # comm
      webcord
      telegram-desktop
      signal-desktop
      cinny-desktop
      fractal
      simplex-chat-desktop

      # bitcoin
      # bisq-desktop
      trezor-suite
      trezor-udev-rules

      # misc
      betaflight-configurator
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # tools
        "${pkgs.kitty}/bin/kitty"
        "${pkgs.obsidian}/bin/obsidian"

        # comms
        "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop}/bin/signal-desktop"
        "${pkgs.cinny-desktop}/bin/cinny"
      ];
      bind = [
        "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"
      ];
    };

    services = {
      udiskie.enable = true;
    };

    programs = {
      # hyprland
      hyprland.enable = true;
      kitty.enable = true;
      obs-studio.enable = false;
      waybar.enable = true;

      # browsers
      chromium.enable = true;
      firefox.enable = true;

      vscode = {
        enable = true;
        userSettings = {
          "chat.editor.fontFamily" = "RobotoMono Nerd Font Mono";
          "chat.editor.fontSize" = 13;
          "debug.console.fontFamily" = "RobotoMono Nerd Font Mono";
          "debug.console.fontSize" = 13;
          "editor.fontFamily" = "RobotoMono Nerd Font Mono";
          "editor.fontSize" = 13;
          "editor.inlayHints.fontFamily" = "RobotoMono Nerd Font Mono";
          "editor.inlineSuggest.fontFamily" = "RobotoMono Nerd Font Mono";
          "editor.minimap.sectionHeaderFontSize" = 9;
          "markdown.preview.fontFamily" = "RobotoMono Nerd Font Mono";
          "markdown.preview.fontSize" = 13;
          "scm.inputFontFamily" = "RobotoMono Nerd Font Mono";
          "scm.inputFontSize" = 12;
          "screencastMode.fontSize" = 53;
          "terminal.integrated.fontSize" = 13;
          "editor.tabSize" = 2;
          "editor.minimap.enabled" = false;
        };
      };

      # utils
      pandoc.enable = true;
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      email_client.enable = true;
    };
  };
}
