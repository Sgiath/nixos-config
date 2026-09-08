{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  imports = [
    ./audio.nix
    ./bitcoin.nix
    ./chromium.nix
    ./clipboard.nix
    ./comm.nix
    ./editors.nix
    ./email_client.nix
    ./file_explorer.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./noctalia.nix
    ./secrets.nix
    ./ssh.nix
    ./starship.nix
    ./stt.nix
    ./stylix.nix
    ./tmux.nix
    ./web_browsers.nix
    ./worktrunk.nix
    ./zsh.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    home = {
      stateVersion = "23.11";

      packages = with pkgs; [
        pkgs.${namespace}.update
        pkgs.${namespace}.fix-images
        pkgs.${namespace}.clear-cache

        # general programs I want to have always available
        imagemagick
        ffmpeg
        zip
        unzip
        p7zip
        wget
        dig
        killall
        inotify-tools
        lshw
        parted
        nix-du
        exfat
      ];
    };

    services = {
      pass-secret-service.enable = true;
    };

    programs = {
      home-manager.enable = true;
      fastfetch.enable = true;

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      password-store = {
        enable = true;
        settings = {
          PASSWORD_STORE_DIR = "${config.xdg.dataHome}/password-store";
        };
        package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
      };
    };

    systemd.user.startServices = "sd-switch";
  };
}
