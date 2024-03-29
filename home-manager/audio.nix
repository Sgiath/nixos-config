{ pkgs, ... }:

{
  home.packages = [ pkgs.qpwgraph ];
  services.easyeffects.enable = true;
}
