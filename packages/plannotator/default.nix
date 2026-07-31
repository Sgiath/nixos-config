{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation rec {
  pname = "plannotator";
  version = "0.25.1";

  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/plannotator-linux-x64";
    hash = "sha256-UWJWL7uX91SpyDwNdJ/GLSC6zeUJzV0v7MAEkL2d/m8=";
  };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/plannotator

    runHook postInstall
  '';

  meta = with lib; {
    description = "Annotate and review coding agent plans and code diffs visually";
    homepage = "https://plannotator.ai";
    license = licenses.asl20;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
