{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      base16Scheme = ../../../themes/sgiath.yaml;

      # The Home Manager module is imported unconditionally from flake.nix so
      # stylix.targets.* options exist on headless hosts too.
      homeManagerIntegration.autoImport = false;

      targets.kmscon.enable = false;
    };
  };
}
