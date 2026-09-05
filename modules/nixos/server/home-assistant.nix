{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.home-assistant.enable) {
    sops.secrets.matrix_password.restartUnits = [ "home-assistant.service" ];
    systemd.services.home-assistant = {
      serviceConfig = {
        LoadCredential = [ "matrix-password:${config.sops.secrets.matrix_password.path}" ];
        RuntimeDirectory = "home-assistant-secrets";
        RuntimeDirectoryMode = "0700";
      };
      preStart = lib.mkBefore ''
        umask 077
        ${pkgs.jq}/bin/jq -Rs . < "$CREDENTIALS_DIRECTORY/matrix-password" \
          > /run/home-assistant-secrets/matrix-password.json
      '';
    };

    services = {
      nginx.virtualHosts."home-assistant.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8123";
        };
      };

      home-assistant = {
        extraPackages =
          python3Packages: with python3Packages; [
            psycopg2
            gtts
            pymetno
          ];
        extraComponents = [
          # custom
          "openweathermap"
          "shelly"
          # "tuya"
          # "tplink"
          # "tplink_tapo"
          "roborock"
          # "starlink"
          # "bitcoin"
        ];
        config = {
          http = {
            server_host = [ "127.0.0.1" ];
            server_port = 8123;
            use_x_forwarded_for = true;
            trusted_proxies = [
              "127.0.0.1"
              "192.168.1.0/24"
            ];
          };
          homeassistant = {
            name = "Home";
            latitude = 49.84582092775863;
            longitude = 18.181012180054974;
            temperature_unit = "C";
            time_zone = "UTC";
            unit_system = "metric";
          };

          # default config
          config = { };
          dhcp = { };
          energy = { };
          history = { };
          image_upload = { };
          mobile_app = { };
          ssdp = { };
          sun = { };
          zeroconf = { };
          matrix = {
            homeserver = "https://matrix.sgiath.dev";
            username = "@sgiath:sgiath.dev";
            password = "!include /run/home-assistant-secrets/matrix-password.json";
            rooms = [
              "#home-assistant:sgiath.dev"
            ];
          };
        };
      };
    };
  };
}
