{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.eve.enable) {
    services.nginx.virtualHosts."eve.sgiath.dev" = {
      # SSL
      onlySSL = true;
      kTLS = true;

      # ACME
      enableACME = true;
      acmeRoot = null;

      locations."/" = {
        proxyPass = "http://192.168.1.6:4000";
      };
    };
  };
}
