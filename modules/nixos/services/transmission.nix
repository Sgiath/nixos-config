{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.roles.server.enable && config.services.transmission.enable) {
    sops.secrets.transmission.restartUnits = [ "transmission.service" ];
    systemd.services.transmission = {
      serviceConfig.LoadCredential = [ "password:${config.sops.secrets.transmission.path}" ];
      serviceConfig.ExecStartPre = lib.mkBefore [
        "${pkgs.writeShellScript "transmission-credentials" ''
          umask 077
          ${pkgs.jq}/bin/jq -Rs '{"rpc-password": .}' \
            < "$CREDENTIALS_DIRECTORY/password" \
            > /run/transmission/credentials.json
        ''}"
      ];
    };

    services = {
      transmission = {
        openPeerPorts = true;
        performanceNetParameters = true;
        package = pkgs.transmission_4;
        webHome = pkgs.flood-for-transmission;
        credentialsFile = "/run/transmission/credentials.json";

        settings = {
          download-dir = "/nas/downloads";
          rpc-authentication-required = true;
          rpc-username = "sgiath";
        };
      };

      nginx.virtualHosts."torrent.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
          proxyWebsockets = true;
        };
      };
    };
    systemd.services.nginx.after = [ "transmission.service" ];
  };
}
