{
  sgiath.enable = true;

  programs = {
    git.enable = true;
    gpg.enable = true;
    nvim.enable = true;
    ssh.enable = true;
    starship.enable = true;
    tmux.enable = true;
    zsh.enable = true;
  };

  services = {
    osmscout-server = {
      enable = true;
      network.startWhenNeeded = false;
    };
  };
}
