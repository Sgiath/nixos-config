{ inputs, userSettings, ... }:

{
  imports = [ inputs.nix-bitcoin.nixosModules.default ];

  nix-bitcoin = {
    generateSecrets = true;
    operator = {
      enable = true;
      name = "${userSettings.username}";
    };
  };

  services = {
    bitcoind.enable = false;
    clightning.enable = false;
  };
}
