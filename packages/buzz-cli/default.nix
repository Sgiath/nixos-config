{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "buzz-cli";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    tag = "v${version}";
    hash = "sha256-VWqoIS5FMyou6fEuuUq1OUIPycAtn0kVLbm5yCQAsOs=";
  };

  cargoHash = "sha256-0a0SJqDjSTWXU6k3yZ6iisDaUdnHqzjZU33ItzGs8AY=";

  cargoBuildFlags = [
    "-p"
    "buzz-cli"
  ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  doCheck = false;

  meta = {
    description = "Agent-first command-line client for Buzz";
    homepage = "https://github.com/block/buzz";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "buzz";
    platforms = lib.platforms.linux;
  };
}
