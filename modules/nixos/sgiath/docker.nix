{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.docker = {
    enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf config.sgiath.docker.enable {
    virtualisation = {
      docker = {
        enable = true;
        # Workstations: start after boot via docker.timer so dockerd is not
        # on graphical.target's critical chain. restart=always compose
        # projects come up once the daemon is running. Servers keep boot start.
        enableOnBoot = config.sgiath.server.enable;
        logDriver = "local";
        extraPackages = with pkgs; [
          docker-credential-helpers
          amazon-ecr-credential-helper
        ];
      };

      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    systemd.timers.docker = lib.mkIf (!config.sgiath.server.enable) {
      description = "Start Docker after boot without blocking login";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15s";
        AccuracySec = "1s";
      };
    };

    users.users.sgiath.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-credential-helpers
      amazon-ecr-credential-helper
    ];
  };
}
