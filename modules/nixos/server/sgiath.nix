{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable) {
    services = {
      nginx.virtualHosts."sgiath.dev" = {
        root = "/data/www/sgiath.dev";

        locations = {
          "/download" = {
            extraConfig = ''
              autoindex on;
              autoindex_exact_size off;
              autoindex_format html;
            '';
            tryFiles = "$uri $uri/ $uri.zip $uri/index.html =404";
          };

          "/sgiath.asc" = {
            extraConfig = ''
              add_header Content-Disposition 'attachment';
            '';
          };
        };
      };
    };
  };
}
