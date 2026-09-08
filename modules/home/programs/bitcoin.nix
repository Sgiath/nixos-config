{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  config = lib.mkIf config.sgiath.programs.bitcoin.enable {
    home.packages = with pkgs; [
      inputs.btc-clients.packages.${pkgs.stdenv.hostPlatform.system}.bisq
      trezor-suite
      trezor-udev-rules
    ];
  };
}
