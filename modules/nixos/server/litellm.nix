{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.litellm.enable) {
    services = {
      litellm = {
        port = 11111;
        settings = {
          general_settings = { };
          litellm_settings = { };
          router_settings = { };
          model_list = [ ];
        };
      };

      nginx.virtualHosts."llm-proxy.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:11111";
        };
      };
    };

    systemd.services.nginx.after = [ "litellm.service" ];
  };
}
