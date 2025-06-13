{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.ntfy.enable) {
    services = {
      ntfy = {
        settings = {
          base-url = "https://ntfy.sgiath.dev";
          listen-http = ":5679";
          behind-proxy = true;
        };
      };

      nginx.virtualHosts."ntfy.sgiath.dev" = {
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
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:5679";
        };
      };
    };
  };
}