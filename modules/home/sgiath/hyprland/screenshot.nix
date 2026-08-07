{
  lib,
  pkgs,
  ...
}:
let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp} -b 1B1F28CC -c E06B74ff -s C778DD0D -w 2)" - \
      | ${lib.getExe pkgs.satty} \
        --filename - \
        --output-filename "~/Pictures/Screenshots/%Y-%m-%dT%H%M%S.png" \
        --copy-command wl-copy \
        --floating-hack
  '';
  command = lib.getExe screenshot;
in
{
  home.packages = [
    screenshot
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      {
        _args = [
          "SUPER + S"
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})")
        ];
      }
    ];

    window_rule = [
      {
        match.class = "com.gabm.satty";
        float = true;
      }
    ];
  };
}
