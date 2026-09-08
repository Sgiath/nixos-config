{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    users.users.sgiath = import ./account.nix // {
      linger = true;
      extraGroups = [
        "wheel"
        "input"
        "gamemode"
      ];
    };

    users.defaultUserShell = pkgs.zsh;
    environment.sessionVariables = {
      SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
    };
    programs = {
      nix-ld.enable = true;
    };
  };
}
