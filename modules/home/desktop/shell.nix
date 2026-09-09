{
  config,
  lib,
  pkgs,
  ...
}:
# Which desktop shell owns the session: Noctalia or the in-repo Quickshell
# config. Both units are always installed and conflict with each other, so
# `systemctl --user start` of one stops the other; `sgiath.desktop.shell` only
# decides which one graphical-session.target pulls in at login.
let
  cfg = config.sgiath.desktop;
  target = config.wayland.systemd.target;
  wantedBy = shell: lib.mkForce (lib.optional (cfg.shell == shell) target);

  noctalia = lib.getExe config.programs.noctalia.package;
  qs = lib.getExe config.programs.quickshell.package;

  desktopShell = pkgs.writeShellApplication {
    name = "desktop-shell";
    text = ''
      usage() {
        echo "usage: desktop-shell noctalia|sgiath|toggle|status|launcher|session" >&2
        exit 2
      }

      sgiath_active() {
        systemctl --user is-active --quiet quickshell.service
      }

      case "''${1:-}" in
        noctalia) systemctl --user start noctalia.service ;;
        sgiath) systemctl --user start quickshell.service ;;
        toggle)
          if sgiath_active; then exec "$0" noctalia; else exec "$0" sgiath; fi
          ;;
        status)
          for unit in noctalia quickshell; do
            printf '%s\t%s\n' "$unit" "$(systemctl --user is-active "$unit.service" || true)"
          done
          ;;
        # Keybind targets. The Quickshell config answers these through
        # IpcHandler { target: "<name>" } with a toggle() function.
        launcher | session)
          if sgiath_active; then
            exec ${qs} -c sgiath ipc call "$1" toggle
          else
            exec ${noctalia} msg panel-toggle "$1"
          fi
          ;;
        *) usage ;;
      esac
    '';
  };

  exec = command: lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})";
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = [ desktopShell ];

    systemd.user.services = {
      noctalia = {
        Unit.Conflicts = [ "quickshell.service" ];
        Install.WantedBy = wantedBy "noctalia";
      };
      quickshell = {
        Unit.Conflicts = [ "noctalia.service" ];
        Install.WantedBy = wantedBy "sgiath";
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + SHIFT + Q"
          (exec "${lib.getExe desktopShell} session")
        ];
      }
      {
        _args = [
          "SUPER + slash"
          (exec "${lib.getExe desktopShell} launcher")
        ];
      }
    ];
  };
}
