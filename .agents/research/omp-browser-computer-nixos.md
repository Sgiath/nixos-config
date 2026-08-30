# OMP browser and computer tools on NixOS

## Scope

The local flake pins `oh-my-pi` v18.0.11. Current upstream source was also checked because the browser and computer implementations continue to change between releases.

## Browser

OMP's `browser` tool uses `puppeteer-core` and Chrome DevTools Protocol. It resolves a browser in this order: `PUPPETEER_EXECUTABLE_PATH`, a detected system Chromium, then a downloaded Chrome for Testing. On NixOS, relying on the downloaded generic Linux archive is fragile because its dynamic loader and shared-library assumptions do not match an unmodified NixOS host.

The graphical Home Manager profile already installs `ungoogled-chromium`. Set `PUPPETEER_EXECUTABLE_PATH` to that wrapped Nix executable. This removes the accidental dependency on `google-chrome-stable` from the CrazyEgg profile and prevents the generic Chrome download fallback.

Relevant upstream source:

- [tool registration and enablement](https://github.com/can1357/oh-my-pi/blob/969062200754ea02cfac922e5ebb8c608c079e15/packages/coding-agent/src/tools/index.ts#L462-L480)
- [browser mode selection](https://github.com/can1357/oh-my-pi/blob/969062200754ea02cfac922e5ebb8c608c079e15/packages/coding-agent/src/tools/browser.ts#L94-L131)
- [Chromium resolution and download fallback](https://github.com/can1357/oh-my-pi/blob/969062200754ea02cfac922e5ebb8c608c079e15/packages/coding-agent/src/tools/browser/launch.ts#L192-L248)
- [NixOS-specific Chromium candidates](https://github.com/can1357/oh-my-pi/blob/969062200754ea02cfac922e5ebb8c608c079e15/packages/coding-agent/src/tools/browser/launch.ts#L338-L376)

## Computer

On Linux, `DesktopSession` selects Wayland whenever `WAYLAND_DISPLAY` is set. There is no fallback to X11 when Wayland capture or input fails.

The Wayland paths are separate:

- Capture: xdg-desktop-portal ScreenCast plus PipeWire. The native addon must be built with the optional `wayland-pipewire` feature. Upstream Nix packaging exposes this as `omp.override { withWaylandScreencast = true; }`; it is disabled by default.
- Accessibility: AT-SPI through `org.a11y.Bus`. NixOS had `services.gnome.at-spi2-core.enable = false`, which also exported `NO_AT_BRIDGE=1` and `GTK_A11Y=none`. The observed OMP capability state was `ax: false`, and `desktop.windows()` failed because `org.a11y.Bus` was not activatable.
- Input: libei through `org.freedesktop.portal.RemoteDesktop.ConnectToEIS`, or an explicit `LIBEI_SOCKET`.

The local system already enables PipeWire, xdg-desktop-portal, `xdg-desktop-portal-hyprland`, and `xdg-desktop-portal-gtk`. The required local changes are therefore:

1. Build graphical OMP installations with `withWaylandScreencast = true`.
2. Enable NixOS `services.gnome.at-spi2-core`.

Relevant upstream source:

- [computer tool registration and enablement](https://github.com/can1357/oh-my-pi/blob/969062200754ea02cfac922e5ebb8c608c079e15/packages/coding-agent/src/tools/index.ts#L462-L480)
- [Linux backend selection](https://github.com/can1357/oh-my-pi/tree/969062200754ea02cfac922e5ebb8c608c079e15/crates/pi-natives/src/desktop/linux)
- [Nix package feature switch](https://github.com/can1357/oh-my-pi/blob/v18.0.11/nix/package.nix)
- [RemoteDesktop portal contract](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html)

## Hyprland input limitation

`xdg-desktop-portal-hyprland` currently advertises Screenshot, ScreenCast, GlobalShortcuts, and InputCapture, but not RemoteDesktop. InputCapture is the opposite libei direction: it receives captured physical input; OMP needs to send synthetic input. Hyprland also does not expose a sender-compatible `LIBEI_SOCKET`.

Consequently, this configuration supports browser automation, Wayland screenshots, clipboard access, and AT-SPI accessibility. Native pointer and keyboard injection remains unavailable under Hyprland until the upstream RemoteDesktop implementation lands. Adding GNOME, KDE, or wlr portals does not fix that under Hyprland and risks portal selection conflicts. The unofficial `xdg-desktop-portal-hypr-remote` proof of concept was rejected as an unmaintained, unpackaged security-sensitive component.

Primary sources:

- [xdg-desktop-portal-hyprland advertised interfaces](https://github.com/hyprwm/xdg-desktop-portal-hyprland/blob/master/hyprland.portal)
- [open Hyprland RemoteDesktop issue](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/252)
- [open RemoteDesktop implementation PR](https://github.com/hyprwm/xdg-desktop-portal-hyprland/pull/308)
