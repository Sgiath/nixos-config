{ lib, ... }:
{
  imports = [
    ./gpu.nix
    ./gpu-amd.nix
    ./gpu-nvidia.nix
    ./razer.nix
  ];

  options.sgiath.hardware = {
    gpu = lib.mkOption {
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

    kernel = lib.mkOption {
      type = lib.types.enum [
        "zen"
        "xanmod"
      ];
      default = "zen";
      example = "xanmod";
      description = "Which kernel package set to boot";
    };

    boot = lib.mkOption {
      type = lib.types.enum [
        "uefi"
        "legacy"
      ];
      default = "uefi";
      example = "legacy";
    };

    razer.enable = lib.mkEnableOption "Razer notebook";
  };
}
