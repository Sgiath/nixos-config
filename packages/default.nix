pkgs: {
  bird = pkgs.callPackage ./bird { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  delta = pkgs.callPackage ./delta { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  grok-bot = pkgs.callPackage ./grok-bot { };
  nak = pkgs.callPackage ./nak { };
  nordic-gtk-theme = pkgs.callPackage ./nordic-gtk-theme { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  xurl = pkgs.callPackage ./xurl { };
}
