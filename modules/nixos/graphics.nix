{ config, lib, pkgs, ...}:
{
  options.sgiath.gpu = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "amd" "nvidia" ]);
    default = null;
    example = "amd";
    description = "What GPU configuration to use";
  };

  config = lib.mkIf (config.sgiath.gpu != null) {
    hardware.graphics.enable = true;
    # MS fonts needed for KSP
    fonts.packages = with pkgs; [ corefonts ];
  };
}
