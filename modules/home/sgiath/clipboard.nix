{
  config,
  lib,
  pkgs,
  ...
}:
let
  command = "${lib.getExe pkgs.kitty} --class clipse -e ${lib.getExe pkgs.clipse}";
in
{
  config = lib.mkIf config.programs.hyprland.enable {
    services.clipse.enable = true;
    home.packages = with pkgs; [
      wl-clipboard
      wl-clipboard-x11
    ];
    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + V"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})")
          ];
        }
      ];
      window_rule = [
        {
          match.class = "clipse";
          float = true;
          size = "622 652";
          stay_focused = true;
        }
      ];
    };
  };
}
