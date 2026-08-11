{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  bubblewrap,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  nspr,
  nss,
  pango,
  stdenv,
  systemd,
  wrapGAppsHook3,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "codex-desktop";
  version = "26.803.81509";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.803.81509_amd64.deb";
    hash = "sha256-qb+Ro2j598Tuo4CCqfuPtGuNAFtxmm13FdLloZgsOOs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    stdenv.cc.cc
    systemd
  ];

  runtimeDependencies = [ systemd ];

  # The app ships optional Qt integration shims and musl prebuilds. Debian does
  # not depend on Qt or musl because those files are loaded only in matching
  # target processes; the glibc prebuilds are used on this platform.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-x86_64.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb -x "$src" .

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -a usr/lib/chatgpt "$out/lib/"
    cp -a usr/share/applications usr/share/pixmaps "$out/share/"

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail "Exec=chatgpt %U" "Exec=codex-desktop %U"

    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/codex-desktop" \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          xdg-utils
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libglvnd
          libsecret
        ]
      }

    ln -s codex-desktop "$out/bin/chatgpt"
    ln -s ${lib.getExe bubblewrap} "$out/bin/bwrap"

    runHook postInstall
  '';

  preFixup = ''
    wrapProgram "$out/lib/chatgpt/ChatGPT" \
      "''${gappsWrapperArgs[@]}"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "OpenAI Codex and ChatGPT desktop application";
    homepage = "https://openai.com/codex/";
    license = lib.licenses.unfree;
    mainProgram = "codex-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
