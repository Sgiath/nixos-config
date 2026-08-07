{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ccflare;
  stateDirectory = "${config.xdg.stateHome}/ccflare";
  environment = cfg.extraEnvironment // {
    PORT = toString cfg.port;
    LB_STRATEGY = "session";
    LOG_LEVEL = cfg.logLevel;
    LOG_FORMAT = cfg.logFormat;
    ccflare_CONFIG_PATH = "${stateDirectory}/ccflare.json";
    ccflare_DB_PATH = "${stateDirectory}/ccflare.db";
  };
in
{
  options.services.ccflare = {
    enable = lib.mkEnableOption "ccflare user service";

    package = lib.mkPackageOption pkgs.sgiath "ccflare" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port on which ccflare listens.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "DEBUG"
        "INFO"
        "WARN"
        "ERROR"
      ];
      default = "INFO";
      description = "ccflare log verbosity.";
    };

    logFormat = lib.mkOption {
      type = lib.types.enum [
        "pretty"
        "json"
      ];
      default = "json";
      description = "ccflare log output format.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables passed to ccflare.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.ccflare = {
      Unit = {
        Description = "ccflare API proxy";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = lib.getExe' cfg.package "ccflare-server";
        WorkingDirectory = stateDirectory;
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") environment;
        StateDirectory = "ccflare";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
