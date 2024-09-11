{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.gpu = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "amd"
        "nvidia"
      ]
    );
    default = null;
    example = "amd";
    description = "What GPU configuration to use";
  };

  config = lib.mkIf (config.sgiath.gpu != null) {
    hardware.graphics.enable = true;
    programs = {
      gamescope.enable = true;
      gamemode.enable = true;
      steam = {
        enable = true;
        protontricks.enable = true;
        extraCompatPackages = [
          pkgs.proton-ge-bin
        ];
      };
    };
  };
}
