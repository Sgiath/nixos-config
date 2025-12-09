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
  version = "2.19.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-Aly1WvxmBipgSSD8YjnvxvvVhFCxpP3R75uG3yWPpIc=";
    }
    {
      name = "z02";
      hash = "sha256-DaQpjcjhMQhYX/MRP5lKx1z788V4USDpmi1TLpR+xtg=";
    }
    {
      name = "z03";
      hash = "sha256-Tn/yeIpnpRoT+J9l2VWCA3ejj9zBke6JPHQasMPUmMQ=";
    }
    {
      name = "z04";
      hash = "sha256-Kr96Tu4qOGHCHYecsOFLW9u71bBkgwSqn7NL+0fLYSw=";
    }
    {
      name = "z05";
      hash = "sha256-OvUGu6OQ4WB/c7Sny1PliA2o/w4bESXFWQNJz/eQVgU=";
    }
    {
      name = "z06";
      hash = "sha256-6G4uWpp32ndqSqpDhn6BYMcS5fj+3Ap6QwJAZa69NUM=";
    }
    {
      name = "z07";
      hash = "sha256-2pHORnuaRJohqF2w/S5St7EAQSHZqG9EZzPqbUNtx5E=";
    }
    {
      name = "z08";
      hash = "sha256-Y3d8APR82mck3xIPc2Ak3IJCnxji2TtBvo66dGLM+Jw=";
    }
    {
      name = "z09";
      hash = "sha256-l8TPnxEp4ZQQdKRY7c1+Lxg2Leot/ybd2NV8AWPz2Uk=";
    }
    {
      name = "z10";
      hash = "sha256-uWiTrD25xwHylKd/lcv29GJjtC33CxiH/W0bJ9eT7J0=";
    }
    {
      name = "z11";
      hash = "sha256-/5sgPsiIomRGVYyMa/OExscDnB8eU4j3SkBgWppa+1A=";
    }
    {
      name = "zip";
      hash = "sha256-N5rURyG3iqE0SD3qUJB5j/NXzD1mWVE9KR08OWpOJnw=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.19.1";
        # inherit version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );

  # to update copy new package.json and package-lock.json and run:
  # node2nix -i package.json -l package-lock.json -d
  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-tECi3R/6WiUM4CwzDjfPKieljqkLJRx5tNgmIXKnc7c=";
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
    export PATH="${nodeDependencies}/bin:$PATH"

    # generate service worker
    ${nodejs}/bin/npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
