{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.claude-code = {
      enable = false;
      enableMcpIntegration = true;
      package = pkgs.llm-agents.claude-code;
      context = ./AGENTS.md;
      skills = ./skills;
    };

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.llm-agents.claude-code} --dangerously-skip-permissions";
    };
  };
}
