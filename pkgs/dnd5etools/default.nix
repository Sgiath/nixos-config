{
  lib,
  callPackage,
  stdenv,
  fetchzip,
  nodejs,
  ...
}:
let
  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation rec {
  pname = "5etools";
  version = "1.210.4";

  src = fetchzip {
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-kIXgWA9KZp/vIGApH5kCnzYr4HB65uG4tQmBcUK8VbM=";
  };

  buildInputs = [ nodejs ];

  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
