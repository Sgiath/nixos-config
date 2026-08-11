pkgs: {
  bird = pkgs.callPackage ./bird { };
  buzz = pkgs.callPackage ./buzz { };
  buzz-cli = pkgs.callPackage ./buzz-cli { };
  buzz-relay = pkgs.callPackage ./buzz-relay { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  codex-desktop = pkgs.callPackage ./codex-desktop { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  eve-flipper = pkgs.callPackage ./eve-flipper { };
  gogcli = pkgs.callPackage ./gogcli { };
  graphify = pkgs.callPackage ./graphify { };
  grok-bot = pkgs.callPackage ./grok-bot { };
  kimi-webbridge = pkgs.callPackage ./kimi-webbridge { };
  linear-cli = pkgs.callPackage ./linear-cli { };
  nak = pkgs.callPackage ./nak { };
  nordic-gtk-theme = pkgs.callPackage ./nordic-gtk-theme { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  orca = pkgs.callPackage ./orca { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code = pkgs.callPackage ./t3code { };
  xurl = pkgs.callPackage ./xurl { };
}
