{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.chromium.enable {
    programs.chromium = {
      package = pkgs.ungoogled-chromium;
      dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
      nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ];
      commandLineArgs = [
        "--password-store=basic"
        "--ozone-platform-hint=wayland"
        "--gtk-version=4"
        "--enable-wayland-ime"
        "--disable-features=ExtensionManifestV2Unsupported"

        "--enable-features=WebUIDarkMode"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"

        "--disable-search-engine-collection"
        "--keep-old-history"
        "--max-connections-per-host=15"
        "--popups-to-tabs"
        "--close-window-with-last-tab=never"

        "--fingerprinting-canvas-image-data-noise"
        "--fingerprinting-canvas-measuretext-noise"
        "--fingerprinting-client-rects-noise"

        "--ssl-key-log-file=/home/sgiath/.ssl_keylog"
      ];
    };

    home.activation.setChromiumAsPdfHandler = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe' pkgs.xdg-utils "xdg-mime"} default chromium-browser.desktop application/pdf
    '';

    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = "chromium-browser";
        workspace = "2 silent";
      }
    ];
  };
}
