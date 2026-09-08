{ lib, pkgs, ... }:
{
  # Shell and key tooling only; no sgiath baseline or roles on the live system.
  home.stateVersion = "23.11";

  programs = {
    home-manager.enable = true;
    git.enable = true;
    gpg.enable = true;
    ssh.enable = true;
    starship.enable = true;
    tmux.enable = true;
    zsh.enable = true;
  };

  services.gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-curses;
}
