{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.matrix-conduit.enable) {
    services = {
      matrix-conduit = {
        package = pkgs.conduwuit.all-features;
        settings.global = {
          # server
          server_name = "matrix.sgiath.dev";
          address = "127.0.0.1";
          port = 6167;

          database_backend = "rocksdb";

          # registration
          allow_registration = true;
          registration_token = secrets.matrix_registration_token;

          # other
          admin_console_automatic = true;
          new_user_displayname_suffix = "";
        };
      };

      # matrix-synapse = {
      #   settings = {
      #     public_baseurl = "https://matrix.sgiath.dev";
      #     enable_registration = true;
      #   };
      # };

      nginx.virtualHosts = {
        "sgiath.dev".locations = {
          "/.well-known/matrix/server" = {
            extraConfig = ''
              default_type application/json;
            '';
            return = "200 '{\"m.server\":\"matrix.sgiath.dev\"}'";
          };

          "/.well-known/matrix/client" = {
            extraConfig = ''
              default_type application/json;
            '';
            return = "200 '{\"m.homeserver\":{\"base_url\":\"matrix.sgiath.dev\"}}'";
          };
        };

        "matrix.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          # static files
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:6167";
          };
        };
      };
    };
  };
}
