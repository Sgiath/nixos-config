{ pkgs, ... }:

{
  imports = [ ./aws.nix ];
  home.packages = [ pkgs.insomnia ];
}
