{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.web_browsers.enable = lib.mkEnableOption "web browsers";

  config = lib.mkIf config.sgiath.web_browsers.enable {
    home.packages = [
      pkgs.tor-browser
      pkgs.zen-browser
    ];

    programs.chromium.enable = true;

    # Firefox
    programs.firefox.enable = false;
    stylix.targets.firefox.enable = false;

    # libre Wolf
    programs.librewolf = {
      enable = true;
      # https://librewolf.net/docs/settings/
      settings = { };
    };

    # qutebrowser
    programs.qutebrowser = {
      enable = true;
      searchEngines = {
        DEFAULT = "https://search.sgiath.dev/search?q={}";
      };
      quickmarks = {
        nixpkgs = "https://github.com/NixOS/nixpkgs";
      };
      # https://qutebrowser.org/doc/help/settings.html
      settings = {
        auto_save.session = true;
        colors.webpage.darkmode.enabled = true;
        url.auto_search = true;
      };
    };
  };
}
