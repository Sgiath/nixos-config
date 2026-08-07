{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ccflare;
in
{
  options.services.ccflare = {
    enable = lib.mkEnableOption "the ccflare API proxy";

    package = lib.mkPackageOption pkgs.sgiath "ccflare" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port on which ccflare listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the ccflare port in the firewall.";
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

  config = lib.mkIf (config.sgiath.enable && cfg.enable) {
    users.users.ccflare = {
      isSystemUser = true;
      group = "ccflare";
      home = "/var/lib/ccflare";
    };
    users.groups.ccflare = { };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port ];

    systemd.services.ccflare = {
      description = "ccflare API proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = cfg.extraEnvironment // {
        PORT = toString cfg.port;
        LB_STRATEGY = "session";
        LOG_LEVEL = cfg.logLevel;
        LOG_FORMAT = cfg.logFormat;
        ccflare_CONFIG_PATH = "/var/lib/ccflare/ccflare.json";
        ccflare_DB_PATH = "/var/lib/ccflare/ccflare.db";
      };

      serviceConfig = {
        User = "ccflare";
        Group = "ccflare";
        ExecStart = lib.getExe' cfg.package "ccflare-server";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "ccflare";
        StateDirectoryMode = "0700";
        UMask = "0077";
        LimitNOFILE = 65536;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/ccflare" ];
      };
    };
  };
}
