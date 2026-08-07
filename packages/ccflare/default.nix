{
  bun,
  cacert,
  fetchFromGitHub,
  lib,
  makeWrapper,
  stdenvNoCC,
}:

let
  version = "0-unstable-2026-04-19";
  rev = "95c4c6a12d11598386333972e04cf1567c5a1298";

  src = fetchFromGitHub {
    owner = "snipeship";
    repo = "ccflare";
    inherit rev;
    hash = "sha256-SlBCR5A79IhFlchm415G4mir2UenfGoQf26rLWVuQ4E=";
  };

  tree = stdenvNoCC.mkDerivation {
    pname = "ccflare-tree";
    inherit version src;

    nativeBuildInputs = [ bun ];
    dontConfigure = true;

    postPatch = ''
      substituteInPlace packages/runtime-server/src/index.ts \
        --replace-fail \
          'const { port = NETWORK.DEFAULT_PORT, withDashboard = true } = options || {};' \
          'const { port = Number(process.env.PORT) || NETWORK.DEFAULT_PORT, withDashboard = true } = options || {};'
    '';

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR"
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

      bun install --frozen-lockfile --no-progress
      bun run build:dashboard

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R ./. "$out/"

      runHook postInstall
    '';

    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-okDrNAUNhm6yGFkccQ2skX+dCSqHFk4E+PxvZgfDD4c=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ccflare";
  inherit version;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"

    makeWrapper ${bun}/bin/bun "$out/bin/ccflare" \
      --add-flags "run tui" \
      --prefix PATH : ${bun}/bin \
      --chdir ${tree}

    makeWrapper ${bun}/bin/bun "$out/bin/ccflare-server" \
      --add-flags "run start" \
      --prefix PATH : ${bun}/bin \
      --chdir ${tree}

    runHook postInstall
  '';

  passthru = { inherit tree; };

  meta = {
    description = "Multi-provider load-balancing proxy for Anthropic and OpenAI";
    homepage = "https://github.com/snipeship/ccflare";
    license = lib.licenses.mit;
    mainProgram = "ccflare";
    platforms = [ "x86_64-linux" ];
  };
}
