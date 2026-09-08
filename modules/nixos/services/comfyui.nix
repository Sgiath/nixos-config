{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.services.comfyui.enable {
    services.comfyui = {
      package = pkgs.comfy-ui-rocm;
      extraArgs = [
        "--disable-xformers"
        "--use-pytorch-cross-attention"
        "--lowvram"
      ];
    };
  };
}
