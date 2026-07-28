{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.remote = {
    enable = lib.mkEnableOption "Remote home manager";
  };

  config = lib.mkIf config.remote.enable {
    home.packages = with pkgs; [
      glab
    ];
  };
}
