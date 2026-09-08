{
  config,
  lib,
  osConfig,
  apiKeyWrapper,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    home.packages = [ apiKeyWrapper ];
    # Only this user's sessions receive API keys; other users and system services do not.
    home.sessionVariablesExtra = ''
      eval "$(${lib.getExe apiKeyWrapper} --shell)"
    '';
    nix.extraOptions = ''
      !include ${osConfig.sops.templates.nix-access-tokens.path}
    '';
  };
}
