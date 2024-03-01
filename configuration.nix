# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nixos"; # Define your hostname.
    networkmanager.enable = true;  # Easiest to use and most distros use this by default.
    firewall.enable = false;
  };

  # Set your time zone.
  time.timeZone = "UTC";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  # Enable the X11 windowing system.
  services = {
    xserver = {
      enable = true;

      # managed by home-manager
      desktopManager.session = [
        {
          name = "xmonad";
          start = ''
            ${pkgs.runtimeShell} $HOME/.xsession &
            waitPID=$!
          '';
        }
      ];

      displayManager = {
        lightdm.enable = true;

        autoLogin = {
          enable = true;
          user = "sgiath";
        };
      };

      # Configure keymap in X11
      xkb = {
        layout = "us";
        options = "caps:escape";
      };
    };

    # Enable CUPS to print documents.
    printing.enable = true;

    # OpenSSH
    openssh.enable = true;
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      sgiath = {
        isNormalUser = true;
        description = "sgiath";
        extraGroups = [ "networkmanager" "wheel" "vboxsf" ];
        packages = [];
      };
    };
  };

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    shells = with pkgs; [ bash zsh nushell ];
    systemPackages = with pkgs; [ neovim wget git ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    zsh.enable = true;
  };

  # do not require password for sudo
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "23.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

