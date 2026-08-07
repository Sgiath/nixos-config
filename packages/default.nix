pkgs: {
  bird = pkgs.callPackage ./bird { };
  buzz = pkgs.callPackage ./buzz { };
  buzz-cli = pkgs.callPackage ./buzz-cli { };
  buzz-relay = pkgs.callPackage ./buzz-relay { };
  ccflare = pkgs.callPackage ./ccflare { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  easy-cli-proxy-api = pkgs.callPackage ./easy-cli-proxy-api { };
  eve-flipper = pkgs.callPackage ./eve-flipper { };
  gogcli = pkgs.callPackage ./gogcli { };
  kimi-webbridge = pkgs.callPackage ./kimi-webbridge { };
  linear-cli = pkgs.callPackage ./linear-cli { };
  nak = pkgs.callPackage ./nak { };
  nordic-gtk-theme = pkgs.callPackage ./nordic-gtk-theme { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  orca = pkgs.callPackage ./orca { };
  plannotator = pkgs.callPackage ./plannotator { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code = pkgs.callPackage ./t3code { };
  xurl = pkgs.callPackage ./xurl { };
}
