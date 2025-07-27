{
  config,
  lib,
  ...
}:
{
  options.services.wordpress.proxy = lib.mkEnableOption "Wordpress proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.wordpress.proxy) {
    services = {
      nginx.virtualHosts = {
        "www.romana-vaverova.cz".globalRedirect = "romana-vaverova.cz";
        "romana-vaverova.cz" = {
          # SSL
          onlySSL = true;
          kTLS = true;
          sslCertificate = "/data/www/romana-vaverova.cz/cert.pem";
          sslCertificateKey = "/data/www/romana-vaverova.cz/key.pem";

          # ACME
          enableACME = false;

          # QUIC
          http3_hq = true;
          quic = true;

          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:8081";
            };
          };
        };
      };
    };
  };
}
