{ config, lib, ... }:
{
  options.services.xmpp = {
    enable = lib.mkEnableOption "XMPP server";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.xmpp.enable) {
    services = {
      prosody = {
        enable = true;
      };
    };
  };
}
