{ writeShellScriptBin }:
writeShellScriptBin "clear-cache" ''
  doas nix-collect-garbage -d
  nix-collect-garbage -d

  doas nix-store --gc
  doas nix-store --optimise

  docker system prune -a -f
  docker volume prune -f

  doas journalctl --vacuum-time=14d
''
