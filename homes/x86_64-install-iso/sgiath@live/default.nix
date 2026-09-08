{
  sgiath = {
    enable = true;
    roles.terminal.enable = true;
  };

  home.file.nixos = {
    recursive = true;
    source = ./../../../.;
  };
}
