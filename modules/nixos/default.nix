{
  imports = [
    # always enabled
    ./optimizations.nix
    ./time_lang.nix
    ./security.nix
    ./boot.nix
    ./mounting_usb.nix

    # enable switch
    ./amd-gpu.nix
    ./nvidia-gpu.nix
  ];
}
