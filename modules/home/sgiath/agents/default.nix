{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./cursor.nix
    ./forge.nix
    ./opencode.nix
    ./pi.nix
  ];

  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.file.".agents/skills".source = ./skills;

    home.packages = [
      pkgs.llm-agents.herdr

      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird
      pkgs.nodejs

      pkgs.llm-agents.backlog-md
      pkgs.llm-agents.openspec
      pkgs.llm-agents.beads
      pkgs.llm-agents.coderabbit-cli
      pkgs.llm-agents.qmd
      pkgs.llm-agents.grok
      pkgs.llm-agents.codegraph
      pkgs.llm-agents.amp

      pkgs.${namespace}.plannotator
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.linear-cli
      pkgs.${namespace}.xurl

      # Hermes
      pkgs.llm-agents.hermes-agent
      pkgs.llm-agents.hermes-desktop
      pkgs.llm-agents.hermes-hud

      # T3 code
      (lib.mkIf (config.sgiath.targets.graphical) pkgs.${namespace}.t3code)
    ];

    programs.zsh.shellAliases = {
      bl = "${lib.getExe pkgs.llm-agents.backlog-md}";
      gr = "${lib.getExe pkgs.llm-agents.grok} --experimental-memory";
    };

    programs.bun.enable = true;

    programs.mcp = {
      enable = true;

      servers = {
        github = {
          url = "https://api.githubcopilot.com/mcp/x/all";
          oauth = false;
          headers = {
            Authorization = "Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}";
            X-MCP-Insiders = "true";
          };
        };
        gitlab.url = "https://gitlab.com/api/v4/mcp";
        linear.url = "https://mcp.linear.app/mcp";
        linear-remote.url = "https://mcp.linear.app/mcp";
        shortcut.url = "https://mcp.shortcut.com/mcp";
        notion-crazyegg.url = "https://mcp.notion.com/mcp";
        notion-remote.url = "https://mcp.notion.com/mcp";
        agent-skills = {
          enabled = false;
          url = "https://agentskills.io/mcp";
        };
      };
    };
  };
}
