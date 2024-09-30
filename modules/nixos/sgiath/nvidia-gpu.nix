{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.gpu == "nvidia") {
    boot.initrd.kernelModules = [ "nvidia" ];
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
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
}
