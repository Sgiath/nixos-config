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
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    tag = "v${version}";
    hash = "sha256-rrTpV4wYRdL1o0cJXifHz5qGJ4tlr2Go1g3MdNrj26w=";
  };

  cargoHash = "sha256-0a0SJqDjSTWXU6k3yZ6iisDaUdnHqzjZU33ItzGs8AY=";

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
