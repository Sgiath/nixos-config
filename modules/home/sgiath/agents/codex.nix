{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ pkgs.llm-agents.codex ];
      file.".codex/AGENTS.md".source = ./AGENTS.md;
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe pkgs.llm-agents.codex} --yolo";
    };
  };
}
