{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      base16Scheme = ../../../themes/yoru.yaml;

      targets.kmscon.enable = false;
    };
  };
}
