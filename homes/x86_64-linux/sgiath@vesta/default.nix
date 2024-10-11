{
  sgiath = {
    enable = true;

    targets = {
      terminal = true;
    };
  };

  services = {
    osmscout-server = {
      enable = true;
      # network.startWhenNeeded = false;
    };
  };
}
