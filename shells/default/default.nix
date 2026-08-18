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
    gh
    gnupg
    jq
    nix-prefetch
    perl
    prefetch-npm-deps
  ];
}
