{ config, lib, ... }:
{
  options.services.nas-proxy.enable = lib.mkEnableOption "NAS proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.nas-proxy.enable) {
    services.nginx.virtualHosts = {
      "nas.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

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
