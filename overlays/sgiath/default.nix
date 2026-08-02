{ inputs, ... }:
final: prev:
let
  llmAgents = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system};

  pkgs-master = import inputs.nixpkgs-master {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  pkgs-ksa = import inputs.nixpkgs-ksa {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  ksa = pkgs-ksa.ksa;
  factorio-space-age-experimental = pkgs-master.factorio-space-age-experimental;
  llm-agents = llmAgents // {
    grok = llmAgents.grok.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        substituteInPlace "$out/bin/grok" "$out/bin/agent" \
          --replace-fail \
          '--dev-bind / / --tmpfs /bin' \
          '--dev-bind / / --dir /bin --tmpfs /bin'
      '';
    });
  };
}
