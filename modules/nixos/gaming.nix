{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.gaming = {
    enable = lib.mkEnableOption "gaming";
  };

  config = lib.mkIf config.sgiath.gaming.enable {
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_xanmod_latest;

    programs = {
      steam = {
        enable = true;
        gamescopeSession.enable = true;
      };

      gamemode.enable = true;
    };

    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
    };
  };
}
