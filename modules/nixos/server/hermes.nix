{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  hermesPackage = pkgs.hermes-agent.override {
    extraDependencyGroups = [
      "matrix"
      "voice"
      "anthropic"
      "firecrawl"
      "youtube"
      "web"
    ];
  };
  stateDir = "/var/lib/hermes-agent";
  birdVesta = pkgs.writeShellApplication {
    name = "bird-vesta";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      CREDS_FILE=${lib.escapeShellArg config.sops.secrets.hermes-bird-env.path}
      SCRAPER_DIR=${lib.escapeShellArg "${stateDir}/workspace/twitter-scraper"}
      BIRD_BIN=${lib.getExe pkgs.${namespace}.bird}
    ''
    + builtins.readFile ./hermes-bird-vesta.sh;
  };
  migrateState = pkgs.writeShellApplication {
    name = "hermes-migrate-state";
    runtimeInputs = with pkgs; [
      (python3.withPackages (ps: [ ps.pyyaml ]))
      rsync
      systemd
    ];
    text = ''
      exec python3 ${./hermes-migrate.py}
    '';
  };
  confinement = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ReadWritePaths = [ stateDir ];
    InaccessiblePaths = [
      "-/run/docker.sock"
      "-/run/podman"
      "-/data"
    ];
    UMask = "0007";
  };
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.hermes-agent.enable) {
    users.groups.hermes.members = [ "sgiath" ];
    # Upstream activation creates the home after migration, without skeleton
    # files that would make an otherwise empty destination ambiguous.
    users.users.hermes.createHome = lib.mkForce false;
    users.users.hermes.extraGroups = lib.mkForce [ ];

    # Only the initial, no-follow state copy runs as root. Upstream setup
    # operates on agent-writable files and must not follow symlinks as root.
    system.activationScripts.hermes-agent-setup.text = lib.mkMerge [
      (lib.mkBefore ''
        (
        set -e
        rm -f /run/hermes-agent-setup.ready
        ${lib.getExe migrateState}
        ${pkgs.util-linux}/bin/setpriv --reuid=hermes --regid=hermes \
          --clear-groups --no-new-privs \
          ${pkgs.coreutils}/bin/env -i PATH="$PATH" HOME=${stateDir} USER=hermes LOGNAME=hermes \
          ${pkgs.bash}/bin/bash -e <<'HERMES_UNPRIVILEGED_SETUP'
        install -d -m 2770 ${stateDir}/.local/bin
        ln -sfn ${lib.getExe pkgs.${namespace}.bird} ${stateDir}/.local/bin/bird
        ln -sfn ${lib.getExe birdVesta} ${stateDir}/.local/bin/bird-vesta
      '')
      (lib.mkAfter ''
        HERMES_UNPRIVILEGED_SETUP
        touch /run/hermes-agent-setup.ready
        )
      '')
    ];

    systemd.services = {
      hermes-agent = {
        after = [ "continuwuity.service" ];
        unitConfig.ConditionPathExists = "/run/hermes-agent-setup.ready";
        serviceConfig = confinement // {
          ProtectHome = lib.mkForce true;
        };
      };
      hermes-dashboard = {
        description = "Hermes Agent web dashboard";
        wantedBy = [ "multi-user.target" ];
        after = [ "hermes-agent.service" ];
        wants = [ "hermes-agent.service" ];
        unitConfig.ConditionPathExists = "/run/hermes-agent-setup.ready";

        path = config.services.hermes-agent.extraPackages;
        serviceConfig = confinement // {
          User = "hermes";
          Group = "hermes";
          WorkingDirectory = stateDir;
          EnvironmentFile = [ "${stateDir}/.hermes/.env" ];
          ExecStart = "${hermesPackage}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
          Restart = "on-failure";
          RestartSec = 5;
        };

        environment = {
          HOME = stateDir;
          HERMES_MANAGED = "false";
          HERMES_DASHBOARD_TUI = "1";
          HERMES_HOME = "${stateDir}/.hermes";
        };
      };
    };

    services = {
      hermes-agent = {
        package = hermesPackage;
        createUser = true;
        user = "hermes";
        group = "hermes";
        inherit stateDir;
        workingDirectory = stateDir;
        addToSystemPackages = true;

        extraPackages = with pkgs; [
          imagemagick
          ffmpeg
          # whisper-cpp-vulkan
          yt-dlp
          jq
          pkgs.${namespace}.xurl
          pkgs.${namespace}.bird
          birdVesta
        ];

        environmentFiles = [ config.sops.secrets.hermes-env.path ];
        environment = {
          HERMES_DASHBOARD_TUI = "1";

          MATRIX_HOMESERVER = "https://matrix.sgiath.dev";
          MATRIX_USER_ID = "@niamh:sgiath.dev";
          MATRIX_ALLOWED_USERS = "@sgiath:sgiath.dev";
          MATRIX_HOME_CHANNEL = "!exHpssN2dwpo9ufw23:sgiath.dev";
          MATRIX_HOME_ROOM = "!exHpssN2dwpo9ufw23:sgiath.dev";
          MATRIX_ENCRYPTION = "false";

          WEBHOOK_ENABLED = "true";
          OBSIDIAN_VAULT_PATH = "~/notes";
          SEARXNG_URL = "https://search.sgiath.dev";
        };

        settings = {
          model = {
            default = "grok-4.6";
            provider = "xai-oauth";
          };
          fallback_model = {
            model = "gpt-5.6-sol";
            provider = "openai-codex";
          };

          auxiliary = {
            web_extract = {
              provider = "openai-codex";
              model = "gpt-5.6-luna";
            };
            title_generation = {
              provider = "openai-codex";
              model = "gpt-5.6-luna";
            };
            # vision = {};
            # compression = {};
            # skills_hub = {};
            # approval = {};
            # mcp = {};
            # kanban_decomposer = {};
            # profile_describer = {};
            # curator = {};
          };

          timezone = "UTC";

          toolsets = [ "all" ];
          terminal = {
            backend = "local";
            cwd = stateDir;
            timeout = 180;
          };

          matrix = {
            require_mention = false;
            free_response_rooms = [
              "!exHpssN2dwpo9ufw23:sgiath.dev"
              "!UJC9AZ04bM93iIVfzf:sgiath.dev"
              "!8XctJQ9bxcnbl2wwB8:sgiath.dev"
              "!snfKPYkaPfv7JU3Qux:sgiath.dev"
              "!10Sk6sJuFifga0t3wX:sgiath.dev"
            ];
          };

          display = {
            personality = "kawaii";
            skin = "mono";
          };

          memory = {
            provider = "holographic";
            memory_enabled = true;
            user_profile_enabled = true;
          };
          plugins = {
            hermes-memory-store = {
              auto_extract = true;
              db_path = "${stateDir}/.hermes/memory_store.db";
              default_trust = 0.5;
              hrr_dim = 1024;
            };
          };

          gateway.platforms.api_server = {
            enabled = true;
            extra = {
              host = "127.0.0.1";
              port = 8642;
            };
          };

          agent = {
            max_turns = 150;
            reasoning_effort = "low";
            tool_use_enforcement = "auto";
          };

          approvals.mode = "off";

          delegation = {
            model = "gpt-5.6-luna";
            provider = "openai-codex";
            max_concurrent_children = 10;
            max_spawn_depth = 2;
          };

          compression = {
            enabled = true;
            codex_gpt55_autoraise = true;
            threshold = 0.5;
            target_ratio = 0.2;
            protect_last_n = 20;
            min_tail_user_messages = 2;
            micro_compact = true;
            threshold_tokens = 100000;
          };

          session_reset = {
            mode = "both";
            idle_minutes = 1440;
            at_hour = 4;
          };

          web = {
            search_backend = "searxng";
            extract_backend = "firecrawl";
          };

          dashboard = {
            theme = "niamh";
            public_url = "https://niamh.sgiath.dev";
            basic_auth = {
              username = "sgiath";
              password_hash = "scrypt$16384$8$1$gow0x1oKM9Z1ZfwoIaYXPA==$SevN0dz3ObnQko0fE5XbmsGqEHfS6NZ+K3qsWdLGyQc=";
              session_ttl_seconds = 604800;
            };
          };

          tts = {
            provider = "xai";
            elevenlabs = {
              model_id = "eleven_multilingual_v2";
              voice_id = "XHqlxleHbYnK8xmft8Vq";
            };

            openai = {
              model = "gpt-4o-mini-tts";
              voice = "maple";
            };

            xai = {
              voice_id = "ara";
              language = "en";
            };
          };

          stt = {
            enabled = true;
            provider = "local";
            local = {
              model = "ggml-large-v3-turbo";
            };
          };

          x_search.model = "grok-4.6";

          moa = {
            default_preset = "default";
            presets = {
              default = {
                enabled = true;

                aggregator = {
                  provider = "openai-codex";
                  model = "gpt-5.6-sol";
                  reasoning_effort = "high";
                };

                reference_models = [
                  {
                    provider = "anthropic";
                    model = "claude-fable-5";
                    reasoning_effort = "high";
                  }
                  {
                    provider = "openai-codex";
                    model = "gpt-5.6-sol";
                    reasoning_effort = "high";
                  }
                  {
                    provider = "xai-oauth";
                    model = "grok-4.5";
                  }
                ];
              };
            };
          };
        };
      };

      nginx.virtualHosts = {
        "niamh.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          locations = {
            "/webhooks" = {
              proxyPass = "http://127.0.0.1:8644";
            };

            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:9119";
              extraConfig = ''
                allow 127.0.0.1;
                allow ::1;
                deny 192.168.1.1;
                allow 192.168.1.0/24;
                deny all;
              '';
            };
          };
        };
      };
    };
  };
}
