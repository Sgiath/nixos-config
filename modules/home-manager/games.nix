{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{
  options.sgiath.games = {
    enable = lib.mkEnableOption "games";
  };

  config = lib.mkIf config.sgiath.games.enable {
    home = {
      packages = with pkgs; [
        corefonts
        vistafonts

        (lutris.override {
          extraPkgs = pkgs: [ pkgs.adwaita-icon-theme pkgs.corefonts pkgs.vistafonts ];
        })
        ckan

        # Minecraft
        (prismlauncher.override {
          jdks = [
            jdk21
            jdk8
          ];
        })

        # Factorio
        (factorio.override {
          username = "Sgiath";
          token = secrets.factorio_token;
        })
      ];
    };
  };
}
