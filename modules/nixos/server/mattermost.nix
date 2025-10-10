{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.mattermost.enable) {
    services = {
      mattermost = {
        siteName = "Sgiath Chat";
        siteUrl = "https://chat.sgiath.dev";
        mutableConfig = false;

        plugins = [
          ./mattermost/mattermost-plugin-focalboard-v8.0.0-linux-amd64.tar.gz
        ];

        database = {
          peerAuth = true;
        };
      };

      nginx.virtualHosts."chat.sgiath.dev" = {
        # SSL
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8065";
          proxyWebsockets = true;
        };
      };
    };
  };
}
