{ config, lib, ... }:
{
  options.services.sinai-camp.proxy = lib.mkEnableOption "sinai.camp proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.sinai-camp.proxy) {
    services = {
      nginx.virtualHosts."sinai.camp" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        root = "/data/www/sinai.camp";

        locations = {
          "/download" = {
            extraConfig = ''
              autoindex on;
              autoindex_exact_size off;
              autoindex_format html;
            '';
            tryFiles = "$uri $uri/ $uri.zip $uri/index.html =404";
          };

          "/" = {
            return = "301 https://www.vystupnavrchol.cz";
          };
        };
      };
    };
  };
}
