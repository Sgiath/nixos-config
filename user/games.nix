{ config, pkgs, nix-citizen, ...}:
let
  pkgs-citizen = nix-citizen.packages.${pkgs.system};
in
{
  home = {
    packages = [
      pkgs.discord
      pkgs.lutris

      pkgs.winePackages.unstableFull
      pkgs.winePackages.fonts
      pkgs.winetricks

      # Star Citizen
      pkgs-citizen.star-citizen
      pkgs-citizen.star-citizen-helper
      pkgs-citizen.lug-helper
    ];
  };
}
