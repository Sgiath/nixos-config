{
  lib,
  stdenv,
  autoPatchelfHook,
  bash,
  cairo,
  copyDesktopItems,
  coreutils,
  dbus,
  fetchurl,
  gdk-pixbuf,
  gsettings-desktop-schemas,
  gst_all_1,
  glib,
  gtk3,
  librsvg,
  libsoup_3,
  makeDesktopItem,
  replaceVars,
  webkitgtk_4_1,
  wrapGAppsHook3,
}:

let
  pname = "easy-cli-proxy-api";
  version = "0.2.16";
  srcHash = "sha256-ph5nnBAIP0iGRS3xyshSiPUQJwvuHLpqw4/FbQHoqy0=";
  iconHash = "sha256-k++FGcabudip3asHFWqDKhH+/YloDMXbY4zTStzkTJ0=";

  src = fetchurl {
    url = "https://github.com/router-for-me/EasyCLIProxyAPI/releases/download/v${version}/EasyCLIProxyAPI-v${version}-Linux-amd64.tar.gz";
    hash = srcHash;
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/router-for-me/EasyCLIProxyAPI/v${version}/src-tauri/icons/icon.png";
    hash = iconHash;
  };

  launcher = replaceVars ./launcher.sh {
    inherit version;
    bash = lib.getExe bash;
    coreutils = lib.getBin coreutils;
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontWrapGApps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    gsettings-desktop-schemas
    gst_all_1.gst-plugins-base
    glib
    gtk3
    librsvg
    libsoup_3
    webkitgtk_4_1
  ];

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "EasyCLIProxyAPI";
      comment = "Desktop manager for CLIProxyAPI";
      exec = pname;
      icon = pname;
      categories = [ "Utility" ];
      startupNotify = true;
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 EasyCLIProxyAPI "$out/libexec/easy-cli-proxy-api/EasyCLIProxyAPI"
    install -Dm644 core-version.txt portable-app.json \
      -t "$out/libexec/easy-cli-proxy-api"
    cp -r cpa-core "$out/libexec/easy-cli-proxy-api/"

    install -Dm755 ${launcher} "$out/bin/${pname}"
    ln -s ${pname} "$out/bin/EasyCLIProxyAPI"
    install -Dm644 ${icon} "$out/share/icons/hicolor/256x256/apps/${pname}.png"

    runHook postInstall
  '';

  postFixup = ''
    wrapGApp "$out/bin/${pname}" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
  '';

  passthru = {
    inherit src;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Desktop GUI for CLIProxyAPI";
    homepage = "https://github.com/router-for-me/EasyCLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
