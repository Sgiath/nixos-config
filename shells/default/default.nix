{
  pkgs,
  mkShell,
  ...
}:
mkShell {
  packages = with pkgs; [
    nil
    nixd
    nixfmt
    nixfmt-tree
    nodejs
    shfmt
    prettier

    # package updater
    curl
    dpkg
    gnupg
    jq
    nix-prefetch
    nix-prefetch-github
    perl
    prefetch-npm-deps
  ];
}
