{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.buzz-relay;
  secretsFile = "/var/lib/buzz-secrets/environment";
  relayUrl = "wss://${cfg.domain}";
  mediaUrl = "https://${cfg.domain}/media";
  databaseUrl = "postgresql:///${cfg.databaseName}?host=/run/postgresql&user=buzz";
  redisUrl = "redis://127.0.0.1:${toString cfg.redisPort}";
  minioUrl = "http://127.0.0.1:${toString cfg.minioPort}";
in
{
  options.services.buzz-relay = {
    enable = lib.mkEnableOption "the Buzz collaborative relay";

    package = lib.mkPackageOption pkgs.sgiath "buzz-relay" { };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "ai.sgiath.dev";
      description = "Public hostname of the Buzz relay.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    healthPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9102;
    };

    databaseName = lib.mkOption {
      type = lib.types.str;
      default = "buzz";
    };

    redisPort = lib.mkOption {
      type = lib.types.port;
      default = 6380;
    };

    minioPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
    };

    minioConsolePort = lib.mkOption {
      type = lib.types.port;
      default = 9001;
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "buzz-media";
    };

    localNetwork = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
      description = "Network allowed through nginx while relay membership is not configured.";
    };

    ownerPubkey = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9a-fA-F]{64}");
      default = null;
      description = "Hex Nostr pubkey bootstrapped as relay owner. Setting it enables relay membership enforcement.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.domain != "";
        message = "services.buzz-relay.domain must not be empty";
      }
    ];

    users.groups.buzz-secrets = {
      members = [
        "buzz"
        "minio"
      ];
    };
    users.users.buzz = {
      isSystemUser = true;
      group = "buzz";
      home = "/var/lib/buzz";
      createHome = true;
    };
    users.groups.buzz = { };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.databaseName ];
      ensureUsers = [
        {
          name = "buzz";
          ensureDBOwnership = true;
        }
      ];
    };

    services.redis.servers.buzz = {
      enable = true;
      bind = "127.0.0.1";
      port = cfg.redisPort;
    };

    services.minio = {
      enable = true;
      listenAddress = "127.0.0.1:${toString cfg.minioPort}";
      consoleAddress = "127.0.0.1:${toString cfg.minioConsolePort}";
      rootCredentialsFile = secretsFile;
    };

    systemd.services.buzz-secrets = {
      description = "Generate persistent Buzz relay secrets";
      wantedBy = [ "multi-user.target" ];
      before = [
        "minio.service"
        "buzz-minio-bucket.service"
        "buzz-relay.service"
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        install -d -m 0750 -o root -g buzz-secrets /var/lib/buzz-secrets
        if [[ ! -s ${secretsFile} ]]; then
          minio_secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          relay_key="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          git_hmac="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          umask 0027
          tmp="$(mktemp /var/lib/buzz-secrets/environment.XXXXXX)"
          {
            echo 'MINIO_ROOT_USER=buzz'
            echo "MINIO_ROOT_PASSWORD=$minio_secret"
            echo 'BUZZ_S3_ACCESS_KEY=buzz'
            echo "BUZZ_S3_SECRET_KEY=$minio_secret"
            echo "BUZZ_RELAY_PRIVATE_KEY=$relay_key"
            echo "BUZZ_GIT_HOOK_HMAC_SECRET=$git_hmac"
          } > "$tmp"
          chown root:buzz-secrets "$tmp"
          chmod 0440 "$tmp"
          mv "$tmp" ${secretsFile}
        fi
      '';
    };

    systemd.services.minio = {
      requires = [ "buzz-secrets.service" ];
      after = [ "buzz-secrets.service" ];
    };

    systemd.services.buzz-minio-bucket = {
      description = "Create the Buzz object-storage bucket";
      wantedBy = [ "multi-user.target" ];
      environment.HOME = "/root";
      requires = [
        "buzz-secrets.service"
        "minio.service"
      ];
      after = [
        "buzz-secrets.service"
        "minio.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = secretsFile;
      };
      script = ''
        set -euo pipefail
        until ${pkgs.curl}/bin/curl --fail --silent http://127.0.0.1:${toString cfg.minioPort}/minio/health/ready >/dev/null; do
          sleep 1
        done
        ${pkgs.minio-client}/bin/mc alias set buzz ${minioUrl} "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
        ${pkgs.minio-client}/bin/mc mb --ignore-existing buzz/${cfg.bucket}
      '';
    };

    systemd.services.buzz-relay = {
      description = "Buzz collaborative relay";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "postgresql.service"
        "redis-buzz.service"
        "buzz-minio-bucket.service"
      ];
      after = [
        "postgresql.service"
        "redis-buzz.service"
        "buzz-minio-bucket.service"
      ];
      environment = {
        BUZZ_BIND_ADDR = "${cfg.listenAddress}:${toString cfg.port}";
        BUZZ_HEALTH_PORT = toString cfg.healthPort;
        BUZZ_METRICS_PORT = toString cfg.metricsPort;
        BUZZ_AUTO_MIGRATE = "true";
        BUZZ_REQUIRE_AUTH_TOKEN = "false";
        BUZZ_REQUIRE_RELAY_MEMBERSHIP = if cfg.ownerPubkey == null then "false" else "true";
        BUZZ_ALLOW_NIP_OA_AUTH = "true";
        BUZZ_CORS_ORIGINS = "tauri://localhost,http://localhost:1420,https://${cfg.domain}";
        BUZZ_S3_ENDPOINT = minioUrl;
        BUZZ_S3_BUCKET = cfg.bucket;
        BUZZ_S3_REGION = "us-east-1";
        BUZZ_MEDIA_PUBLIC_BASE_URL = mediaUrl;
        BUZZ_GIT_REPO_PATH = "/var/lib/buzz/git";
        BUZZ_GIT_PACK_CACHE_PATH = "/var/cache/buzz/git-packs";
        BUZZ_GIT_CONFORMANCE_PROBE = "true";
        BUZZ_PUSH_GATEWAY_DELIVERY_URL = "";
        DATABASE_URL = databaseUrl;
        REDIS_URL = redisUrl;
        RELAY_URL = relayUrl;
        RUST_LOG = "buzz_relay=info";
      }
      // lib.optionalAttrs (cfg.ownerPubkey != null) {
        RELAY_OWNER_PUBKEY = cfg.ownerPubkey;
      };
      serviceConfig = {
        User = "buzz";
        Group = "buzz";
        EnvironmentFile = secretsFile;
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "buzz";
        CacheDirectory = "buzz";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/var/lib/buzz"
          "/var/cache/buzz"
        ];
      };
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          allow ${cfg.localNetwork};
          deny all;
          client_max_body_size 600m;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };
}
