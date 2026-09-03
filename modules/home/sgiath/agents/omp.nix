{
  config,
  lib,
  pkgs,
  ...
}:
let
  omp = pkgs.omp.override {
    withWaylandScreencast = config.sgiath.targets.graphical;
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ omp ];
      sessionVariables = lib.mkIf config.sgiath.targets.graphical {
        PUPPETEER_EXECUTABLE_PATH = lib.getExe config.programs.chromium.package;
      };
    };

    programs.zsh.shellAliases = {
      omp = "systemd-run --user --scope --quiet --slice=background-build.slice ${lib.getExe omp}";
    };
  };
}
