{ config, pkgs, pkgs-citizen, nix-gaming, ...}:

{
  home = {
    packages = [
      pkgs.discord

      # Star Citizen
      pkgs-citizen.star-citizen
      pkgs-citizen.star-citizen-helper
    ];
  };
}
