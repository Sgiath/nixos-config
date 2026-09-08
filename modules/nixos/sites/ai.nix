{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.ai.enable) {
    services.nginx.virtualHosts = {
      "ai.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations = {
          "/" = {
            proxyWebsockets = true;
            proxyPass = "http://192.168.1.7:62361";
            extraConfig = ''
              proxy_read_timeout 86400;
              proxy_send_timeout 86400;
            '';
          };
        };
      };
    };
  };
}
