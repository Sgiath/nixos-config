pkgs: {
  bird = pkgs.callPackage ./bird { };
  buzz = pkgs.callPackage ./buzz { };
  buzz-cli = pkgs.callPackage ./buzz-cli { };
  buzz-relay = pkgs.callPackage ./buzz-relay { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  codex-desktop = pkgs.callPackage ./codex-desktop { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  grok-bot = pkgs.callPackage ./grok-bot { };
  nak = pkgs.callPackage ./nak { };
  nordic-gtk-theme = pkgs.callPackage ./nordic-gtk-theme { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  xurl = pkgs.callPackage ./xurl { };
}
