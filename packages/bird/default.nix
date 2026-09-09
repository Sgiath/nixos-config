{
  lib,
  stdenv,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bird";
  version = "0.8.0";

  # Vendored: upstream github:steipete/bird is no longer available.
  src = ../../vendor/bird;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-iIcmXnJO2UKRWEUzdeTReUducFVsMMX4vj55orzT4Kk=";
  };

  nativeBuildInputs = [
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  buildInputs = [
    nodejs
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build:dist

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/bird}
    cp -r dist $out/lib/bird/
    cp -r node_modules $out/lib/bird/
    cp package.json $out/lib/bird/

    makeWrapper ${lib.getExe nodejs} $out/bin/bird \
      --add-flags "$out/lib/bird/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Fast X/Twitter CLI for tweeting, replying, and reading via GraphQL API";
    homepage = "https://github.com/steipete/bird";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "bird";
  };
})
