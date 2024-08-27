{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.graphical.enable && config.graphical.gpu == "amd") {
    boot = {
      initrd.kernelModules = [ "amdgpu" ];
      kernelModules = [ "kvm-amd" ];
    };

    services.xserver.videoDrivers = [ "amdgpu" ];

    systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
        amdvlk
      ];
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };
  };
}
