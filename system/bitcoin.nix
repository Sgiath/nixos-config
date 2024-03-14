{ config, ... }:

{
  services = {
    bitcoind.enable = false;
    clightning.enable = false;
  };
}
