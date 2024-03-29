{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local config = wezterm.config_builder()

      config.enable_tab_bar = false
      config.warn_about_missing_glyphs = false

      return config
    '';
  };
}
