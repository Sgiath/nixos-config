{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openspec";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    rev = "v${finalAttrs.version}";
    hash = "sha256-OvD9i1MN5U9YqL+JmLETessvatI8Eu2Rwze3ONJqZXc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 1;
    hash = "sha256-NiWw9+VDrYVl2seQvrKjn9s5L6T4zWz0OKh+ha5O9Ks=";
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
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/openspec}
    cp -r dist node_modules package.json $out/lib/openspec/

    makeWrapper ${nodejs}/bin/node $out/bin/openspec \
      --add-flags "$out/lib/openspec/dist/cli/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Spec-driven development (SDD) for AI coding assistants.";
    homepage = "https://openspec.dev/";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "openspec";
  };
})
