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
  configDirectory = builtins.dirOf configPath;
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
        remote-management = {
          allow-remote = false;
          secret-key = secrets.cliproxyapi_management;
          disable-control-panel = false;
        };
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
        Initial CLIProxyAPI configuration. Home Manager seeds this configuration
        when it is absent; CLIProxyAPI owns the writable file afterwards. The
        initial authentication directory is ${stateDirectory}.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.activation.seedCliProxyApiConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      config_path=${lib.escapeShellArg configPath}
      config_directory=${lib.escapeShellArg configDirectory}

      if [[ -L "$config_path" ]]; then
        target="$(${pkgs.coreutils}/bin/readlink -f "$config_path")"
        ${pkgs.coreutils}/bin/install -Dm600 "$target" "$config_path.mutable"
        ${pkgs.coreutils}/bin/rm "$config_path"
        ${pkgs.coreutils}/bin/mv "$config_path.mutable" "$config_path"
      elif [[ ! -e "$config_path" ]]; then
        ${pkgs.coreutils}/bin/install -d -m700 "$config_directory"
        ${pkgs.coreutils}/bin/install -m600 ${configFile} "$config_path"
      fi
    '';

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
