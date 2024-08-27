{
  outputs,
  pkgs,
  userSettings,
  ...
}:

{
  imports = [ outputs.nixosModules ];

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
      extraGroups = [ "wheel" ];
      hashedPassword = userSettings.hashedPassword;
    };
  };
}
