{
  config,
  lib,
  pkgs,
  ...
}:
let
  omp = pkgs.omp.override { withWaylandScreencast = true; };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ omp ];

    # programs.omp = {
    #   enable = true;
    #   settings = {
    #     symbolPreset = "nerd";
    #     theme.dark = "dark-starfall";
    #     disabledProviders = [
    #       "claude"
    #       "codex"
    #       "gemini"
    #       "opencode"
    #       "github"
    #     ];
    #   };
    # };
  };
}
