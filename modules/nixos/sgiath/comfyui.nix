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
      environment = {
        PYTORCH_ALLOC_CONF = "expandable_segments:True";
      };
    };
  };
}
