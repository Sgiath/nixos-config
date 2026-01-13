{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "bdui";
  version = "0.2.0";

  src = fetchurl {
    url = "https://github.com/assimelha/bdui/releases/download/v${version}/bdui-linux-x64";
    hash = "sha256-f+O7vrd5xRIwQchjJ+Z2bJo/H7g+ig9dmEtDFqEdzLY=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/bdui
    runHook postInstall
  '';

  meta = with lib; {
    description = "A beautiful TUI visualizer for the bd (beads) issue tracker";
    homepage = "https://github.com/assimelha/bdui";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bdui";
  };
}
