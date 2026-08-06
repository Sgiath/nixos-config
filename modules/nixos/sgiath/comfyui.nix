{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.services.comfyui.enable {
    services.comfyui = {
      gpuSupport = "rocm";
      extraArgs = [
        "--disable-xformers"
        "--use-pytorch-cross-attention"
        "--lowvram"
      ];
    };
  };
}
