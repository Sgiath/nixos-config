{
  wayland.windowManager.hyprland.settings = {
    window_rule = [
      # Disable blur for xwayland context menus
      {
        match.class = "^()$";
        match.title = "^()$";
        no_blur = true;
      }
      # Disable blur for all xwayland apps
      {
        match.xwayland = true;
        no_blur = true;
      }
      # Disable blur for every window
      {
        match.class = ".*";
        no_blur = true;
      }

      # No shadow for tiled windows (matches windows that are not floating).
      {
        match.float = false;
        no_shadow = true;
      }
    ];
  };
}
