{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shell = "\${pkgs.zsh}/bin/zsh";
    clock24 = true;
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.copycat
      tmuxPlugins.open
      tmuxPlugins.prefix-highlight
      {
        plugin = tmuxPlugins.yank;
        extraConfig = ''
          set -g @yank_selection 'clipboard' # or 'secondary' or 'primary'
          set -g @yank_selection_mouse 'clipboard' # or 'primary' or 'secondary'
        '';
      }
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-boot 'on'
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
  };
}
