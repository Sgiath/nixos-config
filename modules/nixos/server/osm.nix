{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.osmscout-server.enable) {
    services = {
      nginx = {
        virtualHosts."osm.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          # static files
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:8553";
          };
        };
      };
    };
  };
}
