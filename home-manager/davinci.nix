{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.davinci = {
    enable = lib.mkEnableOption "DaVinci Resolve";
  };

  config = lib.mkIf config.sgiath.davinci.enable {
    home.packages = with pkgs; [
      davinci-resolve-studio

      # audio convertor
      (writeShellScriptBin "convert-audio" ''
        for i in *.mp4; do
          name=$(echo "$i" | cut -d'.' -f1)
          ${ffmpeg}/bin/ffmpeg -i "$i" -c:v copy -c:a pcm_s321e "$\{name\}.mov"
        done
      '')
    ];
  };
}
