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
  version = "2.22.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-fWir9jw0de03Nr7IPgBV74Q00AFibf50zuFLCveGuxo=";
    }
    {
      name = "z02";
      hash = "sha256-B05o/amcw2T/a0XOhiQSia2iK5oPPQRBY7lj+en/eio=";
    }
    {
      name = "z03";
      hash = "sha256-DCEFaGlY7VgHlz9ax6BBDg1ob7Jedg63BbtH0fjsf6Q=";
    }
    {
      name = "z04";
      hash = "sha256-x2yQ352Ybv5Ja2eyzTKUYXGvNB0mrNQH8Gfurr+33SM=";
    }
    {
      name = "z05";
      hash = "sha256-+tmf1NQDFRXv35q/t0rXyEynaORs/VvlD3lmoUQgqg8=";
    }
    {
      name = "z06";
      hash = "sha256-d2aAgNMaApXkmJBQAJL4vb5izQmRAnA+LcZoQrimwqE=";
    }
    {
      name = "z07";
      hash = "sha256-gfJAwQ5pfSF449Cwt7UhpnHbS/7dsJTvqgsvebq2Gmg=";
    }
    {
      name = "z08";
      hash = "sha256-3YSFupQq3M+BEPGL5PnmOXECVjPYQzox9FhfJv7C0wc=";
    }
    {
      name = "z09";
      hash = "sha256-jtYMF8Kf/sjsMn4foeI0Xp9mAJeXbH3K50QEU9LKhyE=";
    }
    {
      name = "z10";
      hash = "sha256-juuMKUKeBv1vH3fbS3mjLJ2TL/vyQRi35m7xeAkE6s4=";
    }
    {
      name = "z11";
      hash = "sha256-o5RUCmgLj+qR/Ypa3GhsrCTiZXgy9CsIOtE8noKODQE=";
    }
    {
      name = "zip";
      hash = "sha256-hAi9uhyW8h7CA5E5Hh1rQ5DEGgc835W/8Ie7P0HTaYo=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.22.0";
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
    hash = "sha256-HgmyXWeq9JfkRMaU8pl6EXQySAAKHEya5G0sEhh9bq0=";
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
