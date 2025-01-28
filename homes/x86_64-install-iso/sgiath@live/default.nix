{
  sgiath = {
    enable = true;
    targets.terminal = true;
  };

  home.file.nixos = {
    recursive = true;
    source = ./../../..;
  };
}
