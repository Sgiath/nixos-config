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
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
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
  pipewire,
  qt5,
  qt6,
  stdenv,
  systemd,
  wayland,
  wrapGAppsHook3,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "codex-desktop";
  version = "26.810.52044";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.810.52044_amd64.deb";
    hash = "sha256-cIoVobt24rt/DjduUUU5H6J3rTpkBXwdMlN73CobTm4=";
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
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
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
    pipewire
    stdenv.cc.cc
    systemd
    wayland
  ];

  # Electron loads these at runtime rather than linking them directly. Put
  # them on each ELF object's RPATH without leaking a broad LD_LIBRARY_PATH
  # into Electron's Node and Chromium children.
  runtimeDependencies = [
    libGL
    libgbm
    libsecret
    pipewire
    systemd
    wayland
  ];

  # The archive includes musl, glibc, and Android prebuilds for a few Node
  # modules. NixOS uses the glibc variants, so the other runtimes are
  # intentionally absent.
  # The Qt shims are optional and selected dynamically, so autoPatchelf cannot
  # resolve both of their runtimes during its direct dependency pass. Their
  # version-specific RPATHs are added in postFixup below.
  autoPatchelfIgnoreMissingDeps = [
    "libc++_shared.so"
    "libc.musl-x86_64.so.1"
    "liblog.so"
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
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

    # @parcel/watcher uses detect-libc in a named worker. Its process.report
    # fallback trips a CFI guard in the bundled Owl/Electron runtime on NixOS,
    # which shows up as SIGILL / "illegal hardware instruction".
    # Keep the replacement the same length so the asar offsets remain valid;
    # detect-libc will use its ELF/filesystem/ldd fallbacks instead.
    appAsar="$out/lib/chatgpt/resources/app.asar"
    grep -aFq "isLinux() && process.report" "$appAsar"
    sed -i 's/isLinux() \&\& process\.report/false \/\* nix:skip report \*\//' "$appAsar"
    ! grep -aFq "isLinux() && process.report" "$appAsar"
    grep -aFq "false /* nix:skip report */" "$appAsar"

    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/codex-desktop" \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          xdg-utils
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

  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [ qt5.qtbase ]} \
      "$out/lib/chatgpt/libqt5_shim.so"
    patchelf --add-rpath ${lib.makeLibraryPath [ qt6.qtbase ]} \
      "$out/lib/chatgpt/libqt6_shim.so"
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
