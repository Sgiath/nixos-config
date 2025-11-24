{ lib, stdenvNoCC, fetchFromGitHub, rename }:

stdenvNoCC.mkDerivation {
  pname = "material-symbols";
  version = "4.0.0-unstable-2025-09-19";

  src = fetchFromGitHub {
    owner = "google";
    repo  = "material-design-icons";
    rev   = "bb04090f930e272697f2a1f0d7b352d92dfeee43";
    hash  = "sha256-aFKG8U4OBqh2hoHYm1n/L4bK7wWPs6o0rYVhNC7QEpI=";
    sparseCheckout = [ "variablefont" ];
  };

  nativeBuildInputs = [ rename ];

  installPhase = ''
    runHook preInstall

    # Tidy filenames (drop [FILL,GRAD,opsz,wght] suffix)
    rename 's/\[FILL,GRAD,opsz,wght\]//g' variablefont/*

    mkdir -p "$out/share/fonts/truetype"
    cp variablefont/*.ttf "$out/share/fonts/truetype/"

    mkdir -p "$out/share/fonts/woff2"
    cp variablefont/*.woff2 "$out/share/fonts/woff2/"

    runHook postInstall
  '';

  meta = {
    description = "Material Symbols icons by Google (variable fonts)";
    homepage    = "https://fonts.google.com/icons";
    license     = lib.licenses.asl20;
    platforms   = lib.platforms.all;
  };
}
