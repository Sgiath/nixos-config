{ lib, ... }:
{
  imports = [
    ./role.nix
    ./chromium.nix
    ./clipboard.nix
    ./hyprland.nix
    ./noctalia.nix
    ./quickshell.nix
    ./shell.nix
    ./stylix.nix
    ./voxtype.nix
    ./yazi.nix
  ];

  options.sgiath = {
    roles.desktop.enable = lib.mkEnableOption "desktop role";

    desktop = {
      shell = lib.mkOption {
        type = lib.types.enum [
          "noctalia"
          "sgiath"
        ];
        default = "noctalia";
        description = ''
          Desktop shell started with the graphical session. `desktop-shell`
          switches between them at runtime; this only picks the login default.
        '';
      };

      quickshell.live = lib.mkEnableOption ''
        running the `sgiath` Quickshell config straight from the repository
        checkout (~/nixos) so edits hot-reload without a rebuild, plus QML
        tooling (qmlls, qmlformat) for editing it
      '';
    };
  };
}
