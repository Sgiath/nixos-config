{
  outputs,
  config,
  pkgs,
  userSettings,
  ...
}:

{
  imports = [
    outputs.nixosModules
    ./bluetooth.nix
    ./gaming.nix
    ./stylix.nix
    ./audio.nix
    ./wayland.nix
    ./printing.nix
    ./networking.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    earlySetup = true;
    useXkbConfig = true;
  };

  # OpenSSH

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      ${userSettings.username} = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "openrazer"
          "docker"
          "dialout"
        ];
        hashedPassword = userSettings.hashedPassword;
      };
    };
  };

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.stable-packages
    ];

    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ ];
    };
  };

  environment = {
    shells = with pkgs; [
      bash
      zsh
    ];
    systemPackages = with pkgs; [
      neovim
      git
    ];
  };

  programs = {
    mtr.enable = true;
    zsh.enable = true;
    dconf.enable = true;
    nix-ld.enable = true;
  };

  # mounting USBs
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    dbus.packages = [ pkgs.gcr ];
  };

  system.stateVersion = "23.11";

  # Nix config
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    channel.enable = false;
  };
}
