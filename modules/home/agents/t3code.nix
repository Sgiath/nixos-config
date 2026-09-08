{
  config,
  lib,
  pkgs,
  apiKeyWrapper,
  ...
}:
let
  cfg = config.services.t3code;
in
{
  options.services.t3code = {
    enable = lib.mkEnableOption "T3 Code background server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.t3code;
      defaultText = lib.literalExpression "pkgs.llm-agents.t3code";
      description = "T3 Code CLI package providing the `t3` binary.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Interface to bind. `0.0.0.0` is reachable on the LAN from other machines and phones.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "HTTP/WebSocket port for the T3 Code server.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `t3 start`.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.sgiath.agents.enable {
      home.packages = [
        pkgs.llm-agents.t3code
      ]
      ++ lib.optionals config.sgiath.roles.desktop.enable [
        pkgs.llm-agents.t3code-desktop
      ];
    })

    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];

      systemd.user.services.t3code = {
        Unit = {
          Description = "T3 Code server";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          # `start --no-browser` rather than `serve`: serve prints a pairing
          # token on every launch, which would land in the journal.
          ExecStart = "${lib.getExe apiKeyWrapper} ${lib.getExe cfg.package} ${
            lib.escapeShellArgs (
              [
                "start"
                "--no-browser"
                "--host"
                cfg.host
                "--port"
                (toString cfg.port)
              ]
              ++ cfg.extraArgs
            )
          }";
          WorkingDirectory = config.home.homeDirectory;
          Environment = [
            "HOME=${config.home.homeDirectory}"
            "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
          ];
          KillMode = "mixed";
          Restart = "always";
          RestartSec = 5;
          UMask = "0077";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
