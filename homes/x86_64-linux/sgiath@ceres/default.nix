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

  sgiath = {
    enable = true;
    games.enable = true;

    targets = {
      terminal = true;
      graphical = true;
    };
  };

  crazyegg.enable = true;
  remote.enable = true;
  services = {
    cli-proxy-api.enable = true;
    t3code.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
