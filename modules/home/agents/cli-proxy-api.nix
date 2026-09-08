{
  config,
  lib,
  pkgs,
  apiKeyWrapper,
  ...
}:
let
  configPath = "${config.xdg.configHome}/cli-proxy-api/config.yaml";
  stateDirectory = "${config.xdg.stateHome}/cli-proxy-api";
in
{
  options.services.cli-proxy-api.enable = lib.mkEnableOption "CLIProxyAPI user service";

  config = lib.mkIf config.services.cli-proxy-api.enable {
    home.packages = [ pkgs.llm-agents.cli-proxy-api ];

    systemd.user.services.cli-proxy-api = {
      Unit = {
        Description = "CLIProxyAPI server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe apiKeyWrapper} ${lib.getExe pkgs.llm-agents.cli-proxy-api} -config ${configPath}";
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
