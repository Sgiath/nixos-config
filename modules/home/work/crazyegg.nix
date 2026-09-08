{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.work.crazyegg.enable {
    home.packages = with pkgs; [
      google-chrome
      insomnia
    ];
  };
}
