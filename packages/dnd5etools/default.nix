{
  lib,
  callPackage,
  stdenv,
  fetchurl,
  fetchzip,
  nodejs,
  p7zip,
  ...
}:
let
  version = "2.12.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-oIwvb/9i/idALq9Xr8DLlV3mZZ5DwpKlCyDI+mpq6wE=";
    }
    {
      name = "z02";
      hash = "sha256-N6fUDSak0WqahSMCcHlWuP5kfOkWNqhOyQIMLwjauA8=";
    }
    {
      name = "z03";
      hash = "sha256-4lwizJr9dsQyqKhd0eVWCJNkaFA90m2LBEILBIhs3sI=";
    }
    {
      name = "z04";
      hash = "sha256-ZhniEMroNVqld/SnVqEC4Egptw+cWj7kWsR29YAFaLs=";
    }
    {
      name = "z05";
      hash = "sha256-7mDCFDbLfZM6783QpwhLrNPvEoiaxhFAxqgphXYXuAI=";
    }
    {
      name = "z06";
      hash = "sha256-bxShnyKFw1jHqQ9L6ah6sKOlpo9uqdYGj4RN0iTD2Ao=";
    }
    {
      name = "z07";
      hash = "sha256-C2Xfd0Xu1AxFAY/F0ZLa3Sp3vUuc6BqOVgAqS7tU8zo=";
    }
    {
      name = "z08";
      hash = "sha256-dw5i8PNT9Ue3LGjmBLYwN07mdvAagpyi0xT7X6OfuwM=";
    }
    {
      name = "z09";
      hash = "sha256-LbJHjVjTjS0EMTYKh2nEMK773C5WONTmnJtd/dKVe2Q=";
    }
    {
      name = "z10";
      hash = "sha256-qcHWs9iOhWt7GQsZH82Z8cHH46oElwBf3OPEGK0mSjw=";
    }
    {
      name = "z11";
      hash = "sha256-HyAfjI6jGzfhW1C5ZQVcZRL5LtlIRBY+sUo2l0Nwg/4=";
    }
    {
      name = "zip";
      hash = "sha256-6eoNnu4p3sbrnEe9ywwoUjzEb+88TZN1U/Q7Y7kfvoU=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.10.0";
        # inherit version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );

  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-kuMdo5dMlZvs+GWcbbw78DqPPZC6jGSl/1rFeGOUMdU=";
  };

  buildInputs = [
    nodejs
    p7zip
  ];

  buildPhase = ''
    # copy images
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # unpack images
    ${p7zip}/bin/7z x -aoa img-v${version}.zip

    # remove ZIP files
    rm -f img-v*

    # link Node deps
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    # export PATH="${nodeDependencies}/bin:$PATH"

    # generate service worker
    ${nodejs}/bin/npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
