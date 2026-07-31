{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "kimi-webbridge";
  version = "latest-2026-07-31";

  src = fetchurl {
    url = "https://kimi-web-img.moonshot.cn/webbridge/latest/releases/kimi-webbridge-linux-amd64";
    hash = "sha256-D5zeOJtIs8v4AwxT5DTXA1WjYe20q/O51EBitMDSeJw=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/kimi-webbridge"

    runHook postInstall
  '';

  meta = {
    description = "Kimi WebBridge daemon and toolkit";
    homepage = "https://kimi-web-img.moonshot.cn/webbridge/install.sh";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.unfree;
    mainProgram = "kimi-webbridge";
    platforms = [ "x86_64-linux" ];
  };
}
