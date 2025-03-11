{
  imports = [
    ./terminal.nix
    ./graphical.nix
  ];

  stylix.targets = {
    vscode.profileNames = [ "default" ];
    firefox.profileNames = [ "default" ];
  };
}
