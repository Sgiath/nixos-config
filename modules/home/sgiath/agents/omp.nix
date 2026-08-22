{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ pkgs.omp ];

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
