{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.ntfy-sh.enable) {
    services = {
      ntfy-sh = {
        settings = {
          base-url = "https://ntfy.sgiath.dev";
          listen-http = ":5689";
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

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:5689";
        };
      };
    };
  };
}
