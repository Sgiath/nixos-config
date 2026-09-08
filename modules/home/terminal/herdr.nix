{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Parse the base16 scheme shared with Stylix; Nix has no YAML reader, and the
  # file only contains `baseXX: "rrggbb"` entries.
  base16 = lib.pipe (builtins.readFile ../../../themes/yoru.yaml) [
    (lib.splitString "\n")
    (lib.concatMap (
      line:
      let
        m = builtins.match ''base(0[0-9A-F]): "([0-9a-fA-F]{6})".*'' line;
      in
      lib.optional (m != null) (lib.nameValuePair "base${lib.elemAt m 0}" "#${lib.elemAt m 1}")
    ))
    lib.listToAttrs
  ];

  palette = {
    background = base16.base00;
    panel = base16.base01;
    surface = base16.base03;
    overlay = base16.base02;
    text = base16.base05;
    red = base16.base08;
    peach = base16.base09;
    yellow = base16.base0A;
    green = base16.base0B;
    teal = base16.base0C;
    blue = base16.base0D;
    mauve = base16.base0E;

    # Intermediate shades Yoru does not define, tuned for Herdr's layered chrome.
    selection = "#302438";
    overlayBright = "#747677";
    subtext = "#a8aaab";
  };
in
{
  programs.herdr = lib.mkIf config.sgiath.roles.terminal.enable {
    enable = true;
    package = pkgs.herdr;
    settings = {
      onboarding = false;

      experimental.kitty_graphics = true;

      theme = {
        name = "terminal";
        custom = {
          accent = palette.green;
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
        accent = palette.red;
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
            format = "%H:%M:%S";
          }
          {
            type = "text";
            text = "  ";
          }
        ];
        tab_bar_right_separator = " · ";
        window_title = "{workspace} - herdr";

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
                  fg = palette.red;
                  bold = true;
                }
              ]
            ];
          };
        };
      };

      keys = {
        split_horizontal = "prefix+quote";
        split_vertical = "prefix+percent";
      };
    };
  };
}
