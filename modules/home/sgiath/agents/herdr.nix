{ pkgs, ... }:
let
  toml = pkgs.formats.toml { };
in
{
  home.packages = [ pkgs.llm-agents.herdr ];

  xdg.configFile."herdr/config.toml" = {
    force = true;
    source = toml.generate "herdr-config.toml" {
      onboarding = false;

      theme.name = "terminal";

      ui = {
        agent_panel_scope = "all";

        toast.delivery = "system";

        sidebar.spaces = {
          row_gap = 0;
          rows = [
            [
              {
                token = "workspace";
                bold = true;
              }
              {
                token = "branch";
                dim = true;
              }
              "git_status"
            ]
          ];
        };
      };
    };
  };
}
