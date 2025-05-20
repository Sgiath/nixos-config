{config, lib, ...}:
{
  config = lib.mkIf config.programs.nixvim.enable {
    programs.nixvim = {
      extraPlugins = [ pkgs.vimPlugins.yorumi ];
      colorscheme = "yorumi";
    };
  };
}