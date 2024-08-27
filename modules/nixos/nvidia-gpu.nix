{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.graphical.enable && config.graphical.gpu == "nvidia") {
    boot.initrd.kernelModules = [ "nvidia" ];
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      graphics.enable = true;

      nvidia = {
        open = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;

        modesetting.enable = true;

        powerManagement = {
          enable = false;
          finegrained = false;
        };

        nvidiaSettings = true;
      };
    };
  };
}
