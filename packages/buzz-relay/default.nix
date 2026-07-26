{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  git,
  makeWrapper,
}:

rustPlatform.buildRustPackage rec {
  pname = "buzz-relay";
  version = "0.4.26";

  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    tag = "v${version}";
    hash = "sha256-4WnTDKw00r1AOsaaAFB/NFPYI0XTB0totLY8shEE+O0=";
  };

  cargoHash = "sha256-rZmZrgbZ2+oWZOzhF3Iq1W5Jev5kYBvT2f0iR+IdiKc=";

  cargoBuildFlags = [
    "-p"
    "buzz-relay"
  ];

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [ openssl ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/buzz-relay \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  meta = {
    description = "Restricted collaborative Nostr relay for Buzz";
    homepage = "https://github.com/block/buzz";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "buzz-relay";
    platforms = lib.platforms.linux;
  };
}
