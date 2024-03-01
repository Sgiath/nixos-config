{ config, ... }:

{
  programs.zsh = {
    enable = true;
    prezto = {
      enable = true;
      pmodules = [
        "environment"
        "terminal"
        "editor"
        "history"
        "directory"
        "tmux"
        "utility"
        "archive"
        "docker"
        "git"
        "gpg"
        "ssh"
        "completion"
        "syntax-highlighting"
        "history-substring-search"
        "autosuggestions"
      ];

	    editor = {
	      dotExpansion = true;
	      promptContext = true;
	    };
    };
  };
}
