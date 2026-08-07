{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../../secrets.json);
  cfg = config.services.cli-proxy-api;
  configPath = "${config.xdg.configHome}/cli-proxy-api/config.yaml";
  stateDirectory = "${config.xdg.stateHome}/cli-proxy-api";
  yaml = pkgs.formats.yaml { };
  configFile = yaml.generate "cli-proxy-api.yaml" (
    cfg.settings
    // {
      auth-dir = stateDirectory;
    }
  );
in
{
  options.services.cli-proxy-api = {
    enable = lib.mkEnableOption "CLIProxyAPI user service";

    package = lib.mkPackageOption pkgs.llm-agents "cli-proxy-api" { };

    settings = lib.mkOption {
      type = yaml.type;
      default = {
        host = "127.0.0.1";
        port = 8317;
        openai-compatibility = [
          {
            name = "openai";
            base-url = "https://api.openai.com/v1";
            api-key-entries = [
              { api-key = secrets.openai; }
            ];
            models = [
              {
                name = "gpt-5.6-sol";
                alias = "gpt-5.6-sol";
              }
              {
                name = "gpt-5.6-terra";
                alias = "gpt-5.6-terra";
              }
              {
                name = "gpt-5.6-luna";
                alias = "gpt-5.6-luna";
              }
            ];
          }
        ];
      };
      description = ''
        CLIProxyAPI configuration. The authentication directory is managed by
        this module and is always set to ${stateDirectory}.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    xdg.configFile."cli-proxy-api/config.yaml".source = configFile;

    systemd.user.services.cli-proxy-api = {
      Unit = {
        Description = "CLIProxyAPI server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} -config ${configPath}";
        WorkingDirectory = stateDirectory;
        StateDirectory = "cli-proxy-api";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
