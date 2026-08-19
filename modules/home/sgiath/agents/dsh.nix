{
  config,
  lib,
  pkgs,
  ...
}:
let
  # port = 3080;
  dsh = pkgs.llm-agents.dsh;
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ dsh ];

    # systemd.user.services.dsh-web = {
    #   Unit = {
    #     Description = "DeepSeek Harness Web service";
    #     After = [ "network.target" ];
    #   };

    #   Service = {
    #     ExecStart = "${lib.getExe dsh} web --host 127.0.0.1 --port ${toString port}";
    #     WorkingDirectory = config.home.homeDirectory;
    #     Restart = "always";
    #     RestartSec = 5;
    #   };

    #   Install.WantedBy = [ "default.target" ];
    # };
  };
}
