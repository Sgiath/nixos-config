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
    ./cli-proxy-api.nix
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
    home.sessionVariables.GROK_SANDBOX = "off";

    home.packages = [
      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird
      pkgs.nodejs
      pkgs.bun

      # agents
      pkgs.llm-agents.grok
      pkgs.llm-agents.prime-agent
      pkgs.llm-agents.goose-cli
      pkgs.llm-agents.t3code
      pkgs.llm-agents.dsh

      # tools
      pkgs.llm-agents.backlog-md
      pkgs.llm-agents.openspec
      pkgs.llm-agents.beads
      pkgs.llm-agents.coderabbit-cli
      pkgs.llm-agents.qmd
      pkgs.llm-agents.codegraph
      pkgs.llm-agents.amp
      pkgs.llm-agents.plannotator
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.linear-cli
      pkgs.${namespace}.xurl

      # Hermes
      pkgs.llm-agents.hermes-agent
      pkgs.llm-agents.hermes-hud
    ]
    ++ (lib.optionals config.sgiath.targets.graphical [
      pkgs.llm-agents.hermes-one
      pkgs.llm-agents.chatgpt
      pkgs.llm-agents.t3code-desktop
      pkgs.${namespace}.grok-bot
    ]);

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
