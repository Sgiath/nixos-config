{ pkgs, ... }:
{
  config = {
    services.tts.servers.chris = {
      enable = true;
      model = null;
    };
  };
}
