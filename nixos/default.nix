{
  outputs,
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

  system.stateVersion = "23.11";

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

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    channel.enable = false;
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users.${userSettings.username} = {
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
}
