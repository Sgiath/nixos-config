{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  pname = "buzz";
  version = "0.5.9";

  src = fetchurl {
    url = "https://github.com/block/buzz/releases/download/desktop-v${version}/Buzz_${version}_amd64.AppImage";
    hash = "sha256-WvTAPbNThcVhqZVkRYtEW2ZZwlLBrHLa8qHIWgwKSic=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  nativeBuildInputs = [ makeWrapper ];

  extraPkgs =
    pkgs: with pkgs; [
      elfutils
      gst_all_1.gst-libav
      gst_all_1.gst-plugins-good
      zstd
    ];

  extraInstallCommands = ''
    wrapProgram $out/bin/buzz \
      --prefix GST_PLUGIN_PATH : /usr/lib64/gstreamer-1.0

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
