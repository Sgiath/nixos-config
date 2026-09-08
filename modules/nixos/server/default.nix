{ config, lib, ... }:
{
  imports = [
    ./minecraft.nix
    ./nginx.nix
  ];

  options.sgiath.roles.server.enable = lib.mkEnableOption "home server role";

  config = lib.mkIf config.sgiath.roles.server.enable {
    # Servers accept Ceres-built closures without trusting arbitrary SSH imports.
    nix.settings.trusted-public-keys = [
      (lib.strings.trim (builtins.readFile ../../../secrets/ceres-cache.pub))
    ];
  };
}
