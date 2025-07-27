{
  config,
  lib,
  ...
}:
{
  options.services.wordpress.proxy = lib.mkEnableOption "Wordpress proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.wordpress.proxy) {
    services = {
      wordpress = {
        webserver = "nginx";
        sites."romana.sgiath.dev" = {
          settings = {
            WP_SITEURL = "https://romana.sgiath.dev";
            WP_HOME = "https://romana.sgiath.dev";
            FORCE_SSL_ADMIN = true;
            AUTOMATIC_UPDATER_DISABLED = true;
          };
        };
      };

      nginx.virtualHosts."romana.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        # locations."/" = {
        #   proxyPass = "http://127.0.0.1:8081";
        # };
      };
    };
  };
}
