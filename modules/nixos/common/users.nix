{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    users.users.sgiath = {
      linger = true;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "input"
        "gamemode"
      ];
      hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3"
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
