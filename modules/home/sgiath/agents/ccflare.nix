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
  environmentArguments = lib.mapAttrsToList (name: value: "${name}=${value}") environment;
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
      };

      Service = {
        ExecStart = "${pkgs.coreutils}/bin/env -i ${lib.escapeShellArgs environmentArguments} ${lib.getExe' cfg.package "ccflare-server"}";
        WorkingDirectory = stateDirectory;
        StateDirectory = "ccflare";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = "read-only";
        ProtectSystem = "strict";
        ReadWritePaths = [ stateDirectory ];
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
