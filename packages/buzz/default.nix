{
  lib,
  appimageTools,
  fetchurl,
  writeShellScript,
}:

let
  pname = "buzz";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/block/buzz/releases/download/v${version}/Buzz_${version}_amd64.AppImage";
    hash = "sha256-rs0C2Sr+XFqiyG9E9LMhvgjBSanSTx3FkFoDc3WV7Gk=";
  };

  launcher = writeShellScript "buzz-desktop" ''
    export GST_PLUGIN_SYSTEM_PATH_1_0=/usr/lib64/gstreamer-1.0
    exec -a "$0" "$0.bin" "$@"
  '';

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
    postExtract = ''
      mv "$out/usr/bin/buzz-desktop" "$out/usr/bin/buzz-desktop.bin"
      install -Dm755 ${launcher} "$out/usr/bin/buzz-desktop"
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  extraPkgs =
    pkgs: with pkgs; [
      elfutils
      gst_all_1.gst-libav
      gst_all_1.gst-plugins-good
      zstd
    ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/Buzz.desktop \
      $out/share/applications/buzz.desktop
    substituteInPlace $out/share/applications/buzz.desktop \
      --replace-fail 'Exec=buzz-desktop' 'Exec=buzz'

    install -Dm444 ${appimageContents}/buzz-desktop.png \
      $out/share/pixmaps/buzz-desktop.png
  '';

  passthru.src = src;

  meta = with lib; {
    description = "Workspace where humans and agents build together";
    homepage = "https://github.com/block/buzz";
    license = licenses.asl20;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
