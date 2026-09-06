#!/usr/bin/env python3
"""Build and validate the selectable Wayland sessions without activating NixOS.

Usage: python3 tests/check_wayland_sessions.py [--flake PATH] [ceres pallas]
"""

import argparse
import configparser
import json
import os
from pathlib import Path
import shlex
import subprocess


CONTRACT = r'''
c: let h = c.home-manager.users.sgiath; in {
  hyprland = c.programs.hyprland.enable && h.wayland.windowManager.hyprland.enable;
  niri = c.programs.niri.enable && h.wayland.windowManager.niri.enable;
  greeter = c.services.greetd.settings.default_session.command;
  desktops = toString c.services.displayManager.sessionData.desktops;
  niriPackage = toString c.programs.niri.package;
  niriConfig = if h.xdg.configFile ? "niri/config.kdl"
    then toString h.xdg.configFile."niri/config.kdl".source else null;
  satellite = if h.wayland.windowManager.niri.xwaylandSatellitePackage != null
    then toString h.wayland.windowManager.niri.xwaylandSatellitePackage else null;
  portal = c.xdg.portal.config.niri or {};
  hmPortal = h.wayland.windowManager.niri.portalPackage;
  hmSystemd = h.wayland.windowManager.niri.systemd.enable;
  checkConfig = h.wayland.windowManager.niri.checkConfig;
  services = builtins.mapAttrs (_: s: {
    wantedBy = s.Install.WantedBy;
    partOf = s.Unit.PartOf;
  }) (builtins.intersectAttrs {
    noctalia = null;
    hyprpolkitagent = null;
    clipse = null;
  } h.systemd.user.services);
}
'''


def check_host(flake, host):
    print(f"Checking {host} desktop sessions", flush=True)
    prefix = f"{flake}#nixosConfigurations.{host}.config"
    data = json.loads(subprocess.check_output([
        "nix", "eval", "--json", "--no-update-lock-file", prefix,
        "--apply", CONTRACT,
    ], text=True))
    assert data["hyprland"], f"{host}: Hyprland must remain available"
    assert data["niri"], f"{host}: Niri system and home session must be enabled"
    assert data["checkConfig"], f"{host}: generated Niri config must be validated"
    assert not data["hmSystemd"] and data["hmPortal"] is None, (
        f"{host}: NixOS must own Niri systemd units and portals"
    )
    assert "gnome" in data["portal"]["default"], "Niri screencasting portal missing"
    for name in ("noctalia", "hyprpolkitagent", "clipse"):
        service = data["services"][name]
        assert "graphical-session.target" in service["wantedBy"], name
        assert "graphical-session.target" in service["partOf"], name

    greeter = shlex.split(data["greeter"])
    assert "--remember-session" in greeter, "session choice must survive logout"
    assert greeter[greeter.index("--cmd") + 1] == "start-hyprland", (
        "first login must retain the existing Hyprland default"
    )
    session_dir = Path(greeter[greeter.index("--sessions") + 1])
    assert session_dir == Path(data["desktops"]) / "share/wayland-sessions"
    assert greeter[greeter.index("--xsessions") + 1] == "", "unexpected X11 session search"

    subprocess.run([
        "nix", "build", "--no-link", "--no-update-lock-file",
        prefix + ".services.displayManager.sessionData.desktops",
        prefix + '.home-manager.users.sgiath.xdg.configFile."niri/config.kdl".source',
        prefix + ".home-manager.users.sgiath.wayland.windowManager.niri.xwaylandSatellitePackage",
    ], check=True)
    for filename, launcher in (("hyprland.desktop", "start-hyprland"),
                               ("niri.desktop", "niri-session")):
        entry = configparser.ConfigParser(interpolation=None)
        assert entry.read(session_dir / filename), f"missing {filename}"
        command = shlex.split(entry["Desktop Entry"]["Exec"])
        assert any(Path(arg).name == launcher for arg in command), command
        print(f"  {entry['Desktop Entry']['Name']}: {shlex.join(command)}", flush=True)

    niri = Path(data["niriPackage"]) / "bin/niri"
    assert os.access(Path(data["satellite"]) / "bin/xwayland-satellite", os.X_OK)
    assert os.access(niri.with_name("niri-session"), os.X_OK)
    subprocess.run([str(niri), "validate", "--config", data["niriConfig"]], check=True)
    print(f"PASS: {host} sessions, shared services, portals and Niri config", flush=True)
    print(f"  Greeter: {data['greeter']}", flush=True)
    print(f"  Niri config: {data['niriConfig']}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flake", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("hosts", nargs="*", default=["ceres", "pallas"])
    args = parser.parse_args()
    for host in args.hosts:
        check_host(args.flake.resolve(), host)


if __name__ == "__main__":
    main()
