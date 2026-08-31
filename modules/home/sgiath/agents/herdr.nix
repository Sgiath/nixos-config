{ pkgs, ... }:
let
  # Yoru with restrained intermediate shades for Herdr's layered chrome.
  palette = {
    background = "#0c0e0f";
    panel = "#121415";
    surface = "#1f2122";
    selection = "#302438";
    overlay = "#565859";
    overlayBright = "#747677";
    subtext = "#a8aaab";
    text = "#edeff0";
    red = "#f26e74";
    peach = "#ecd28b";
    yellow = "#e79881";
    green = "#82c29c";
    teal = "#6791c9";
    blue = "#709ad2";
    mauve = "#c58cec";
  };
in
{
  programs.herdr = {
    enable = true;
    package = pkgs.llm-agents.herdr;
    settings = {
      onboarding = false;

      theme = {
        name = "terminal";
        custom = {
          accent = palette.red;
          panel_bg = palette.background;
          sidebar_bg = palette.panel;
          active_row_bg = palette.surface;
          selection_bg = palette.selection;

          surface0 = palette.panel;
          surface1 = palette.surface;
          surface_dim = palette.background;
          overlay0 = palette.overlay;
          overlay1 = palette.overlayBright;
          text = palette.text;
          subtext0 = palette.subtext;

          inherit (palette)
            blue
            green
            mauve
            peach
            red
            teal
            yellow
            ;
        };
      };

      ui = {
        accent = palette.green;
        agent_panel_scope = "all";
        agent_panel_sort = "spaces";
        status_indicators = "symbols";

        sidebar_width = 24;
        sidebar_min_width = 20;
        sidebar_max_width = 28;

        pane_borders = true;
        pane_outer_borders = true;
        pane_gaps = true;
        pane_scrollbars = false;

        tab_bar_position = "top";
        tab_bar_right = [
          { type = "zoom"; }
          { type = "hostname"; }
          {
            type = "datetime";
            format = "%H:%M";
          }
        ];
        tab_bar_right_separator = " · ";
        window_title = "{workspace} — herdr";

        toast.delivery = "system";

        sidebar = {
          spaces = {
            row_gap = 1;
            rows = [
              [
                "state_icon"
                {
                  token = "workspace";
                  bold = true;
                }
              ]
              [
                {
                  token = "branch";
                  dim = true;
                }
                "git_status"
              ]
            ];
          };

          agents = {
            row_gap = 1;
            rows = [
              [
                "state_icon"
                {
                  token = "workspace";
                  bold = true;
                }
              ]
              [
                "state_text"
                {
                  token = "agent";
                  fg = palette.mauve;
                  bold = true;
                }
              ]
            ];
          };
        };
      };
    };
  };
}
