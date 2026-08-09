{
  description = "flake-utils-plus compatibility fix for deferred nixpkgs.config";

  inputs.upstream.url = "github:gytis-ivaskevicius/flake-utils-plus/3542fe9126dc492e53ddd252bb0260fe035f2c0f";

  outputs =
    { self, upstream }:
    {
      inherit (upstream)
        blueprints
        darwinModules
        nixosModules
        overlay
        ;

      lib = upstream.lib // {
        mkFlake = import ./lib/mkFlake.nix {
          flake-utils-plus = self;
        };
      };
    };
}
