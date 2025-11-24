{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Uncomment to apply global transparency to all windows:
      #"opacity 0.89 override 0.89 override, match:class .*"

      # Disable blur for xwayland context menus
      "no_blur on, match:class ^()$, match:title ^()$"
      # Disable blur for all xwayland apps
      #"no_blur on, match:xwayland 1"
      # Disable blur for every window
      "no_blur on, match:class .*"

      # No shadow for tiled windows (matches windows that are not floating).
      "no_shadow on, match:float 0"
    ];

    layerrule = [
      "xray 1, match:namespace .*"
      # "layerrule = no_anim on, .*"
      "no_anim on, match:namespace walker"
      "no_anim on, match:namespace selection"
      "no_anim on, match:namespace overview"
      "no_anim on, match:namespace anyrun"
      "no_anim on, match:namespace indicator.*"
      "no_anim on, match:namespace osk"
      "no_anim on, match:namespace hyprpicker"
      "no_anim on, match:namespace no_anim on"
      "blur on, match:namespace gtk-layer-shell"
      # "ignore_zero on, match:namespace gtk-layer-shell"
      "blur on, match:namespace launcher"
      "ignore_alpha 0.5, match:namespace launcher"
      "blur on, match:namespace notifications"
      "ignore_alpha 0.69, match:namespace notifications"
      "blur on, match:namespace logout_dialog" # wlogout

      # ags
      "animation slide left, match:namespace sideleft.*"
      "animation slide right, match:namespace sideright.*"
      "blur on, match:namespace session[0-9]*"
      "blur on, match:namespace bar[0-9]*"
      "ignore_alpha 0.6, match:namespace bar[0-9]*"
      "blur on, match:namespace barcorner.*"
      "ignore_alpha 0.6, match:namespace barcorner.*"
      "blur on, match:namespace dock[0-9]*"
      "ignore_alpha 0.6, match:namespace dock[0-9]*"
      "blur on, match:namespace indicator.*"
      "ignore_alpha 0.6, match:namespace indicator.*"
      "blur on, match:namespace overview[0-9]*"
      "ignore_alpha 0.6, match:namespace overview[0-9]*"
      "blur on, match:namespace cheatsheet[0-9]*"
      "ignore_alpha 0.6, match:namespace cheatsheet[0-9]*"
      "blur on, match:namespace sideright[0-9]*"
      "ignore_alpha 0.6, match:namespace sideright[0-9]*"
      "blur on, match:namespace sideleft[0-9]*"
      "ignore_alpha 0.6, match:namespace sideleft[0-9]*"
      "blur on, match:namespace indicator.*"
      "ignore_alpha 0.6, match:namespace indicator.*"
      "blur on, match:namespace osk[0-9]*"
      "ignore_alpha 0.6, match:namespace osk[0-9]*"

      # quickshell
      "blur_popups on, match:namespace quickshell:.*"
      "blur on, match:namespace quickshell:.*"
      "ignore_alpha 0.79, match:namespace quickshell:.*"
      "animation slide, match:namespace quickshell:bar"
      "no_anim on, match:namespace quickshell:actionCenter"
      "animation slide bottom, match:namespace quickshell:cheatsheet"
      "animation slide bottom, match:namespace quickshell:dock"
      "animation popin 120%, match:namespace quickshell:screenCorners"
      "no_anim on, match:namespace quickshell:lockWindowPusher"
      "animation fade, match:namespace quickshell:notificationPopup"
      "no_anim on, match:namespace quickshell:overlay"
      "ignore_alpha 1, match:namespace quickshell:overlay"
      "no_anim on, match:namespace quickshell:overview"
      "animation slide bottom, match:namespace quickshell:osk"
      "no_anim on, match:namespace quickshell:polkit"
      "xray 0, match:namespace quickshell:popup" # No weird color for bar tooltips (this in theory should suffice)
      "ignore_alpha 1, match:namespace quickshell:popup" # No weird color for bar tooltips (but somehow this is necessary)
      "ignore_alpha 1, match:namespace quickshell:mediaControls" # Same as above
      "animation slide, match:namespace quickshell:reloadPopup"
      "no_anim on, match:namespace quickshell:regionSelector"
      "no_anim on, match:namespace quickshell:screenshot"
      "blur on, match:namespace quickshell:session"
      "no_anim on, match:namespace quickshell:session"
      "ignore_alpha 0, match:namespace quickshell:session"
      "animation slide right, match:namespace quickshell:sidebarRight"
      "animation slide left, match:namespace quickshell:sidebarLeft"
      "animation slide, match:namespace quickshell:verticalBar"
      "animation slide top, match:namespace quickshell:wallpaperSelector"
      "no_anim on, match:namespace quickshell:wOnScreenDisplay"
      
      # Launchers need to be FAST
      "no_anim on, match:namespace gtk4-layer-shell"
    ];
  };
}
