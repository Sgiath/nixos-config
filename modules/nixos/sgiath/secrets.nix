{
  config,
  lib,
  pkgs,
  ...
}:
let
  userKeys = {
    GITHUB_PERSONAL_ACCESS_TOKEN = "github_token";
    GITHUB_TOKEN = "github_token";
    GH_TOKEN = "github_token";
    CLIPROXY_API_KEY = "cliproxy_api_key";
  };
  keyFiles = pkgs.writeText "user-api-key-paths.json" (
    builtins.toJSON (lib.mapAttrs (_: key: config.sops.secrets.${key}.path) userKeys)
  );
  apiKeyWrapper = pkgs.writeShellScriptBin "with-api-keys" ''
    exec ${lib.getExe pkgs.python3} ${./load-api-keys.py} ${keyFiles} "$@"
  '';
  ceresSigningKey = lib.strings.trim (builtins.readFile ../../../public-keys/ceres-cache.pub);
  cachePolicy = (import ../../../flake.nix).nixConfig;
in
{
  config = lib.mkIf config.sgiath.enable {
    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      gnupg.sshKeyPaths = [ ];
      secrets = lib.mkMerge [
        (lib.genAttrs (lib.unique (builtins.attrValues userKeys)) (_: {
          owner = "sgiath";
          mode = "0400";
        }))
        {
          nix-signing-key = lib.mkIf (config.networking.hostName == "ceres") {
            sopsFile = ../../../secrets/ceres-signing.yaml;
            key = "nix-signing-key";
            mode = "0400";
            restartUnits = [ "nix-daemon.service" ];
          };
          hermes-env = lib.mkIf config.services.hermes-agent.enable {
            sopsFile = ../../../secrets/vesta.yaml;
            owner = "hermes";
            key = "hermes-env";
            mode = "0400";
            restartUnits = [
              "hermes-agent.service"
              "hermes-dashboard.service"
            ];
          };
          hermes-bird-env = lib.mkIf config.services.hermes-agent.enable {
            sopsFile = ../../../secrets/vesta.yaml;
            key = "bird-env";
            owner = "hermes";
            mode = "0400";
            restartUnits = [ "hermes-agent.service" ];
          };
          openclaw-token = lib.mkIf (config.networking.hostName == "ceres") {
            owner = "sgiath";
            mode = "0400";
          };
          factorio-token = lib.mkIf config.home-manager.users.sgiath.sgiath.games.enable {
            key = "factorio_token";
            owner = "sgiath";
            mode = "0400";
          };
        }
      ];
      templates.nix-access-tokens = {
        owner = "sgiath";
        mode = "0400";
        content = ''
          access-tokens = github.com=${config.sops.placeholder.github_token}
        '';
      };
    };

    home-manager.extraSpecialArgs = { inherit apiKeyWrapper; };

    # Vesta accepts Ceres-built closures without trusting arbitrary SSH imports.
    nix.settings.trusted-substituters = cachePolicy.extra-substituters;
    nix.settings.trusted-public-keys =
      cachePolicy.extra-trusted-public-keys
      ++ lib.optional (config.networking.hostName == "vesta") ceresSigningKey;

    nix.settings.secret-key-files = lib.mkIf (config.networking.hostName == "ceres") [
      config.sops.secrets.nix-signing-key.path
    ];

  };
}
