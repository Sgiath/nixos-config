{ lib, config, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.zitadel.enable) {
    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [
          "zitadel"
        ];
      };

      zitadel = {
        settings = {
          Port = 8087;
          ExternalPort = 443;
          ExternalDomain = "auth.sgiath.dev";

          postgres = {
            Host = "localhost";
            Port = 5432;
            Database = "zitadel";
            Admin = {
              Username = "postgres";
              Password = "postgres";
            };
          };
        };
        masterKeyFile = "/data/zitadel-key";
        tlsMode = "external";
      };

      nginx.virtualHosts."auth.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:8087";
        };
      };
    };
  };
}
