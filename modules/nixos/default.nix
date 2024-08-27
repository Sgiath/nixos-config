{
  imports = [
    # always enabled
    ./optimizations.nix
    ./time_lang.nix
    ./security.nix

    # enable switch
    ./amd-gpu.nix
    ./nvidia-gpu.nix
  ];
}
