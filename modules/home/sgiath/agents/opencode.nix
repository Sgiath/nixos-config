{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 24096;
  url = "http://127.0.0.1:${toString port}";

  # https://opencode.ai/docs/cli/#environment-variables
  # feature flags are read by the server process; exported in `oc` too so the
  # attach-side TUI/plugins see identical settings
  env = {
    OPENCODE_DISABLE_CLAUDE_CODE = "true";
    OPENCODE_ENABLE_EXA = "true";
    OPENCODE_EXPERIMENTAL = "true";
    OPENCODE_EXPERIMENTAL_FILEWATCHER = "true";
    OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
    OPENCODE_EXPERIMENTAL_EXA = "true";
    OPENCODE_EXPERIMENTAL_WORKSPACES = "true";
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
  };

  envFile = pkgs.writeText "opencode-web.env" (
    lib.concatLines (lib.mapAttrsToList (name: value: "${name}=${value}") env)
  );

  # attach to the persistent server so sessions survive closing the TUI;
  # `--dir` is required, otherwise the server falls back to its own cwd
  oc = pkgs.writeShellApplication {
    name = "oc";
    runtimeInputs = [
      pkgs.curl
      pkgs.llm-agents.opencode
    ];
    text = ''
      ${lib.toShellVars env}
      export ${lib.concatStringsSep " " (builtins.attrNames env)}

      if ! curl -sf --max-time 1 "${url}/global/health" > /dev/null; then
        systemctl --user start opencode-web.service
        for _ in $(seq 1 50); do
          curl -sf --max-time 1 "${url}/global/health" > /dev/null && break
          sleep 0.2
        done
      fi

      if ! curl -sf --max-time 1 "${url}/global/health" > /dev/null; then
        echo "opencode server did not come up on ${url}" >&2
        echo "check: journalctl --user -u opencode-web.service" >&2
        exit 1
      fi

      exec opencode attach "${url}" --dir "$PWD" "$@"
    '';
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ oc pkgs.llm-agents.opencode2 ];

    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      package = pkgs.llm-agents.opencode;

      tui = {
        plugin = [ "oh-my-openagent@latest" ];
        scroll_acceleration = true;
      };

      settings = {
        autoupdate = false;
        plugin = [
          "oh-my-openagent@latest"
          "opencode-claude-auth@latest"
        ];
        permission = {
          bash = {
            "*" = "allow";
            "aws *" = "ask";
            "kubectl exec *" = "ask";
          };
          edit = {
            "*" = "allow";
            "/nix/store/**" = "deny";
          };
          external_directory = {
            "~/**" = "allow";
            "/nix/store/**" = "allow";
            "/tmp/**" = "allow";
          };
        };
        lsp = {
          elixir-ls.disabled = true;
          expert = {
            command = [
              "expert"
              "--stdio"
            ];
            extensions = [
              ".ex"
              ".exs"
              ".eex"
              ".heex"
              ".leex"
              ".neex"
            ];
          };
        };
        formatter = {
          mix.disabled = true;
        };
      };
      web = {
        enable = true;
        environmentFile = envFile;
        extraArgs = [
          "--port"
          "${toString port}"
          "--hostname"
          "127.0.0.1"
        ];
      };
    };
    stylix.targets.opencode.enable = false;

    programs.zsh.shellAliases = {
      omo-update = ''
        pushd ~/.cache/opencode && bun update && popd \
        && pushd ~/.cache/opencode/packages/oh-my-openagent@latest && bun add  oh-my-openagent@latest && popd \
        && pushd ~/.config/opencode && bun add @opencode-ai/plugin@latest && popd
      '';
    };
  };
}
