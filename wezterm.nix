{ config, ... }:

{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      config.enable_tab_bar = false

      -- Font
      config.font = wezterm.font 'RobotoMono Nerd Font'
      config.font_size = 10

      -- Colors
      config.colors = {
        foreground = '#edeff0',
        background = '#0c0e0f',

        cursor_fg = '#0c0e0f',
        cursor_bg = '#edeff0',
        cursor_border = '#edeff0',

        selection_fg = '#928374',
        selection_bg = '#3c3836',

        split = '#6791c9',

        ansi = {
          '#232526',
          '#df6b61',
          '#78b892',
          '#de8f78',
          '#6791c9',
          '#bc83e3',
          '#67afc1',
          '#e4e6e7',
        },
        brights = {
          '#2c2e2f',
          '#e8646a',
          '#81c19b',
          '#e79881',
          '#709ad2',
          '#c58cec',
          '#70b8ca',
          '#f2f4f5',
        }
      }

      return config
    '';
  };
}
