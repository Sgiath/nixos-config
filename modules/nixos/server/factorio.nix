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
  config = lib.mkIf (config.sgiath.server.enable && config.services.factorio.enable) {
    services.factorio = {
      game-name = "sgiath";

      username = "Sgiath";
      token = secrets.factorio_token;
      package = pkgs.factorio-headless-experimental;
    };
  };
}
