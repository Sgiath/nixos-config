{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.hardware.gpu != null) {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
