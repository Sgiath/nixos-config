{ config, systemSettings, inputs, ...}:

{
  imports = [
    inputs.nix-gaming.nixosModules.steamCompat
  ];

  home = {
    packages = [
      # Star Citizen
      inputs.nix-citizen.packages.${systemSettings.system}.star-citizen
      inputs.nix-citizen.packages.${systemSettings.system}.star-citizen-helper
    ];
  };

  programs.steam = {
    enable = true;

    extraCompatPackages = [ ];
  };
}
