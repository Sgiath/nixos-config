{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.plex.enable) {
    services = {
      plex = {
        openFirewall = true;
      };

      nginx.virtualHosts."plex.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:32400";
          proxyWebsockets = true;
        };
      };
    };
  };
}

