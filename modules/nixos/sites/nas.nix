{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.nas.enable) {
    services.nginx.virtualHosts = {
      "nas.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations = {
          "/" = {
            proxyWebsockets = true;
            proxyPass = "http://192.168.1.4:5000";
          };
        };
      };
    };
  };
}
