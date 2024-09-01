{
  config,
  lib,
  userSettings,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    time.timeZone = "UTC";
    services.timesyncd.enable = true;
    i18n.defaultLocale = "en_US.UTF-8";

    environment.sessionVariables = {
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      FLAKE = "/home/${userSettings.username}/.dotfiles";
    };
  };
}
