{
  config,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      texliveMedium
      # lmstudio
      # davinci-resolve-studio
      whisper-cpp-vulkan
    ];

    sessionVariables = {
      # cd ~/.local/share/whisper-cpp && whisper-cpp-download-ggml-model large-v3-turbo
      WHISPER_MODEL = "${config.xdg.dataHome}/whisper-cpp/ggml-large-v3-turbo.bin";
    };
  };

  sgiath.work = {
    crazyegg.enable = true;
    remote.enable = true;
  };

  # Login default stays Noctalia; `desktop-shell sgiath` switches at runtime.
  sgiath.desktop.quickshell.live = true;

  services = {
    cli-proxy-api.enable = true;
    system-failure-watcher.enable = true;
    t3code.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 10;
  };
}
