{
  imports = [
    ./audio.nix
    ./browser.nix
    ./davinci.nix
    ./email_client.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./kitty.nix
    ./ollama.nix
    ./waybar.nix

    # always enabled
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./zsh.nix
  ];
}
