{
  config,
  lib,
  pkgs,
  ...
}:
let
  omp = pkgs.omp.override {
    withWaylandScreencast = config.sgiath.roles.desktop.enable;
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ omp ];
      sessionVariables = lib.mkIf config.sgiath.roles.desktop.enable {
        PUPPETEER_EXECUTABLE_PATH = lib.getExe config.programs.chromium.package;
      };
    };
  };
}
