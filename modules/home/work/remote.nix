{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.work.remote.enable {
    home.packages = with pkgs; [
      glab
    ];
  };
}
