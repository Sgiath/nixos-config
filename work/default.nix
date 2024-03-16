{ pkgs, ... }:

{
  imports = [
    ./aws.nix
  ];

  home.packages = with pkgs; [
    insomnia
  ];
}
