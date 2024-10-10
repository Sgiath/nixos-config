{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.jitsi-meet.enable) {
    services = {
      jitsi-meet = {
        hostName = "meet.sgiath.dev";

        nginx.enable = true;
        prosody.enable = true;
        jibri.enable = true;
        jicofo.enable = true;
        jigasi.enable = true;
        videobridge.enable = true;
      };

      nginx.virtualHosts."meet.sgiath.dev" = {
        # SSL
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;
      };
    };
  };
}
