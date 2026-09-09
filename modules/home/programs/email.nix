{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.programs.email.enable {
    home = {
      packages = with pkgs; [
        claws-mail

        protonmail-bridge-gui
        protonmail-desktop

        proton-vpn
        proton-pass
        proton-pass-cli
        proton-authenticator
      ];

      file.".signature".text = ''
        Filip Vavera
        https://sgiath.dev

        GPG fingerprint:
        B166 3624 D093 688E D5C3 296B 70F9 C7DE 34CB 3BC8

        Why is HTML email a security nightmare? See https://useplaintext.email/
      '';
    };

    xdg.configFile."autostart/ProtonMailBridge.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Proton Mail Bridge
      Exec=${lib.getExe pkgs.protonmail-bridge-gui} --no-window
      Icon=protonmail-bridge-gui
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';

    # Launch once per graphical session, never during Home Manager activation.
    systemd.user.timers.protonmail-desktop = {
      Unit = {
        Description = "Launch Proton Mail at login";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        RefuseManualStart = true;
      };
      Timer = {
        OnActiveSec = "1s";
        AccuracySec = "1s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.protonmail-desktop = {
      Unit = {
        Description = "Proton Mail";
        X-SwitchMethod = "keep-old";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.protonmail-desktop;
        Slice = "app.slice";
      };
    };

    wayland.windowManager.hyprland.settings = {
      window_rule = [
        {
          match.class = "claws-mail";
          workspace = "9 silent";
          no_initial_focus = true;
        }
        {
          match.title = "Proton Mail";
          workspace = "9 silent";
          no_initial_focus = true;
        }
      ];
    };

    services.protonmail-bridge.enable = false;
  };
}
