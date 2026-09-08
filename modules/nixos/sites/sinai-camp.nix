{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.sinai-camp.enable) {
    services = {
      nginx.virtualHosts."sinai.camp" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

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
