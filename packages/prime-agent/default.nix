{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
}:
let
  pname = "prime-agent";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "PrimeIntellect-ai";
    repo = "prime-agent";
    rev = "v${version}";
    hash = "sha256-byn8Est+Jrr/C52nUyJOQmiegCzaEVXeCOHnGsfZB+k=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    nodejs = nodejs_22;
    fetcherVersion = 2;
    postPatch = ''
      npm install --package-lock-only --ignore-scripts
    '';
  };
in
buildNpmPackage {
  inherit
    pname
    version
    src
    npmDeps
    ;

  npmBuildScript = "build";
  npmInstallFlags = [ "--ignore-scripts" ];

  postPatch = ''
    cp ${npmDeps}/package-lock.json package-lock.json
  '';

  nodejs = nodejs_22;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts

    mkdir -p $out/lib/prime-agent
    cp -r package.json packages node_modules $out/lib/prime-agent/

    makeWrapper ${nodejs_22}/bin/node $out/bin/prime-agent \
      --add-flags "$out/lib/prime-agent/packages/coding-agent/dist/bundle/cli.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "RLM-native terminal coding and research agent";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = licenses.mit;
    mainProgram = "prime-agent";
    platforms = platforms.linux;
  };
}
