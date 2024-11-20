{ config, lib, ...}:
{
  config = lib.mkIf config.sgiath.enable {
    services.syncthing = {
      settings = {
        folders = {
          share = {
            enable = true;
            path = "/home/sgiath/share/";
          };
        };
      };
    };
  };
}
