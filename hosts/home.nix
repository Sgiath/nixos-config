{ pkgs, userSettings, ... }:

{
  imports = [
    ../home-manager/gnupg.nix
    ../home-manager/starship.nix
    ../home-manager/zsh.nix
    ../home-manager/tmux.nix
    ../home-manager/ssh.nix
    ../home-manager/nvim.nix
    ../home-manager/git.nix
  ];

  home = {
    username = userSettings.username;
    homeDirectory = "/home/${userSettings.username}";

    stateVersion = "23.11";

    packages = [
      (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; })

      (pkgs.writeShellScriptBin "update" ''
        pushd ~/.dotfiles
        doas nixos-rebuild switch --flake .
        popd
      '')

      (pkgs.writeShellScriptBin "upgrade" ''
        pushd ~/.dotfiles
        nix flake update
        doas nixos-rebuild switch --flake .
        popd
      '')

      (pkgs.writeShellScriptBin "build-iso" ''
        pushd ~/.dotfiles
        nix run "nixpkgs#nixos-generators" -- --format iso --flake ".#installIso" -o result
        popd
      '')

      # general programs I want to have always available
      pkgs.imagemagick
      pkgs.ffmpeg
      pkgs.zip
      pkgs.unzip
      pkgs.wget
      pkgs.dig
      pkgs.killall
      pkgs.inotify-tools
    ];
  };

  programs = {
    home-manager.enable = true;
    bat.enable = true;
    btop.enable = true;
    command-not-found.enable = true;

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    password-store = {
      enable = true;
      package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
    };
  };
}
