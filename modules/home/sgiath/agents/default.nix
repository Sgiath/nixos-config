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
    ./dsh.nix
    ./omp.nix
    ./opencode.nix
    ./pi.nix
    ./t3code.nix
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
      pkgs.llm-agents.goose-cli

      # tools
      pkgs.llm-agents.herdr
      pkgs.llm-agents.td
      pkgs.llm-agents.backlog-md
      pkgs.llm-agents.beads
      pkgs.llm-agents.qmd
      pkgs.llm-agents.codegraph
      pkgs.llm-agents.amp
      pkgs.llm-agents.plannotator
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.xurl

      # Hermes
      pkgs.llm-agents.hermes-agent
    ]
    ++ (lib.optionals config.sgiath.targets.graphical [
      pkgs.llm-agents.hermes-desktop
      pkgs.llm-agents.chatgpt
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
        slack-crazyegg = {
          url = "https://mcp.slack.com/mcp";
          oauth = {
            clientId = "";
            clientSecret = "";
            callbackPort = 3000;
            callbackPath = "/callback";
          };
          auth = {
            type = "oauth";
            clientId = "";
            clientSecret = "";
            credentialId = "mcp_oauth:profile:default:https://mcp.slack.com/mcp";
            tokenUrl = "https://slack.com/api/oauth.v2.user.access";
            resource = "https://mcp.slack.com";
          };
        };
        agent-skills = {
          enabled = false;
          url = "https://agentskills.io/mcp";
        };
      };
    };
  };
}
