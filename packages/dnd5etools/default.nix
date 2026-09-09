{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.35.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-/OLHJKtCOmC7upRJX9IZLyMYh5UPGMQrJoDZnHBJw0M=";
    }
    {
      name = "z02";
      hash = "sha256-hwc4sbqUkDqSArTCX0uDzRxdau7h63EJf7GUuJGjj9s=";
    }
    {
      name = "z03";
      hash = "sha256-sxAWTHvcJFCkR7azyVoiNCSCFt1UwXQYZV5EzdlzDSM=";
    }
    {
      name = "z04";
      hash = "sha256-VcZEqeJanvqUe+yFzMne4J/eZIKUKjNVnh7POt/3Lj8=";
    }
    {
      name = "z05";
      hash = "sha256-W4RvMmEB6r/M0BjRDIlCUeoRfCTJaG9TsMQrR/wtZSA=";
    }
    {
      name = "z06";
      hash = "sha256-Vf1e7j/HnUc1LoMvgUr8Pf4bQjhmtE2TQNcfhdXNNko=";
    }
    {
      name = "z07";
      hash = "sha256-H0ErP5W63anSvRcWKNzYZxlhr2C4g7lDD8SJU4+eC90=";
    }
    {
      name = "z08";
      hash = "sha256-fMCSfgysbWjOLC4hUQjfoa4hm6RS9AVO3DOOAEV0PX4=";
    }
    {
      name = "z09";
      hash = "sha256-sXCnHiCy9kFyy0QhGS4o5ephpwdatIsNnAHsX0SiFkg=";
    }
    {
      name = "z10";
      hash = "sha256-rJ7SqkSxrZkAC8DfAmLXdg+ubhjCpgvc36jcs0eYph0=";
    }
    {
      name = "z11";
      hash = "sha256-rgGomkBxx4GaW68Zflp2iISCrkXfex0QR4hyPyZDx4Q=";
    }
    {
      name = "z12";
      hash = "sha256-dagj1NHB0ikGiTbX10ojSvA+BZxpzIZjLq5D04zECCQ=";
    }
    {
      name = "zip";
      hash = "sha256-8NPNaE7iBxqExdCUhjf5ebxe4Bjm/KlQ8o6b1tDuUSs=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.35.1";
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );
in
buildNpmPackage {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-9SkvHdxBFgVjRhM3KbvFQbCbRVn3cSmQ3TPKMkEBfQ8=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-j/bz7nV8VYl5bWstogiIeua0g+VcMwiDTN7fScd61Cg=";

  nativeBuildInputs = [ p7zip ];

  preBuild = ''
    # Copy image archives
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # Unpack images (split 7z archive)
    ${lib.getExe p7zip} x -aoa img-v${version}.zip

    # Remove archive files
    rm -f img-v*
  '';

  # Build service worker
  npmBuildScript = "build:sw:prod";

  # Don't install as npm package - we want static files
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    # Copy all static files
    cp -r ./ $out/

    # Remove unnecessary files from output
    rm -rf $out/node_modules
    rm -f $out/package*.json

    runHook postInstall
  '';
}
