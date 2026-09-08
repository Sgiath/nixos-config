{ lib, ... }:
{
  imports = [
    ./role.nix
    ./git.nix
    ./gpg.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./worktrunk.nix
    ./zsh.nix
  ];

  options.sgiath.roles.terminal.enable = lib.mkEnableOption "terminal role";
}
