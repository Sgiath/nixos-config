{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.factorio.enable) {
    sops.secrets.factorio_token.restartUnits = [ "factorio.service" ];
    systemd.services.factorio = {
      serviceConfig = {
        LoadCredential = [ "token:${config.sops.secrets.factorio_token.path}" ];
        RuntimeDirectory = "factorio-secrets";
        RuntimeDirectoryMode = "0700";
      };
      preStart = lib.mkBefore ''
        umask 077
        ${pkgs.jq}/bin/jq -Rs '{token: .}' < "$CREDENTIALS_DIRECTORY/token" \
          > /run/factorio-secrets/settings.json
      '';
    };

    services.factorio = {
      game-name = "sgiath";

      username = "Sgiath";
      extraSettingsFile = "/run/factorio-secrets/settings.json";
      package = pkgs.factorio-headless-experimental;
    };
  };
}
