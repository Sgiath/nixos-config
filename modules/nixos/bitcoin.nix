{
  inputs,
  config,
  lib,
  userSettings,
  ...
}:

{
  imports = [ inputs.nix-bitcoin.nixosModules.default ];

  options.sgiath.bitcoin = {
    enable = lib.mkEnableOption "bitcoind";
  };

  config = lib.mkIf config.sgiath.bitcoin.enable {

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
  };
}
