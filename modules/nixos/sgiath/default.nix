{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    # always enabled
    ./boot.nix
    ./mounting_usb.nix
    ./networking.nix
    ./optimizations.nix
    ./security.nix
    ./secrets.nix
    ./stylix.nix
    ./time_lang.nix
    ./udev.nix
    ./yggdrasil.nix

    # enable switch
    ./amd-gpu.nix
    ./audio.nix
    ./bluetooth.nix
    ./comfyui.nix
    ./docker.nix
    ./graphics.nix
    ./nvidia-gpu.nix
    ./ollama.nix
    ./printing.nix
    ./razer.nix
    ./wayland.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    users.users.sgiath = {
      linger = true;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "input"
        "gamemode"
      ];
      hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3"
      ];
    };

    system = {
      stateVersion = "23.11";
    };

    nix = {
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      package = pkgs.nixVersions.latest;
      settings = {
        auto-optimise-store = true;
        require-sigs = true;
        trusted-users = [ "root" ];
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
      };
      channel.enable = false;
      optimise.automatic = true;
      gc = {
        automatic = false;
        dates = "08:00";
      };
    };
    systemd.services.nix-daemon.serviceConfig = {
      MemoryMax = "24G";
      MemoryHigh = "20G";
    };
    home-manager.backupFileExtension = "backup";

    users.defaultUserShell = pkgs.zsh;
    environment.sessionVariables = {
      SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
    };
    programs = {
      nix-ld.enable = true;
    };
  };
}
