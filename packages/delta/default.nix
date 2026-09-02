{
  lib,
  stdenv,
  requireFile,
  autoAddDriverRunpath,
  autoPatchelfHook,
  libgbm,
  libglvnd,
  libx11,
  makeWrapper,
  vulkan-loader,
  wayland,
  xkeyboard_config,
}:

let
  source = import ./source.nix;
in
stdenv.mkDerivation {
  pname = "delta";
  inherit (source) version;

  src = requireFile {
    name = "delta-linux-x86_64.tar.gz";
    inherit (source) hash;
    url = "https://delta.dev";
    message = ''
      Delta requires an authenticated download. Download
      delta-linux-x86_64.tar.gz, place it in packages/delta, then run:

        packages/delta/update.sh
    '';
  };

  sourceRoot = "Delta";
  nativeBuildInputs = [
    autoAddDriverRunpath
    autoPatchelfHook
    makeWrapper
  ];
  runtimeDependencies = [
    libgbm
    libglvnd
    vulkan-loader
    wayland
  ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin lib share $out/
    wrapProgram $out/bin/delta \
      --set XKB_CONFIG_ROOT ${xkeyboard_config}/share/X11/xkb \
      --set XLOCALEDIR ${libx11}/share/X11/locale

    runHook postInstall
  '';

  meta = {
    description = "AI-native code editor";
    homepage = "https://delta.dev";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "delta";
  };
}
