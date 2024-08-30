{ config, lib, ... }:
{
  options.crazyegg.databases = {
    core.enable = lib.mkEnableOption "Core DB";
    metadata.enable = lib.mkEnableOption "Metadata DB";
    metrex.enable = lib.mkEnableOption "Metrex DB";
    redis.enable = lib.mkEnableOption "Redis";
  };

  config = lib.mkIf config.crazyegg.enable {
    services = {
      postgresql =
        lib.mkIf (config.crazyegg.databases.metadata.enable || config.crazyegg.databases.metrex.enable)
          {
            enable = true;
            ensureDatabases = [
              "crazyegg_metadata_master_development"
              "metrex_dev"
            ];
            authentication = ''
              host all postgres samehost trust
            '';
          };

      mysql = lib.mkIf config.crazyegg.databases.core.enable {
        enable = true;
        ensureUsers = [
          {
            name = "root";
            ensurePermissions = {
              "*.*" = "ALL PRIVILEGES";
            };
          }
        ];
        ensureDatabases = [
          "crazyegg2_master_development"
        ];
      };

      redis.servers = lib.mkIf config.crazyegg.databases.redis.enable {
        "0" = {
          enable = true;
          port = 6379;
        };
      };
    };
  };
}
