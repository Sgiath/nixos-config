{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fuse,
  lmdb,
}:

buildGoModule rec {
  pname = "nak";
  version = "0.20.6";

  src = fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${version}";
    hash = "sha256-RNKKkYc6PN/BbYqwUkRWg3o3lzQHg1NONvfqGxQ6t10=";
  };

  vendorHash = "sha256-J1prpdOX2wXfPOkJ/GYetW3Agz5pUeyAj4zBplz4xRw=";

  buildInputs = [
    lmdb
    fuse
  ];

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
  ];

  # tests require network access
  doCheck = false;

  meta = with lib; {
    description = "The nostr army knife - a command line tool for all things nostr";
    homepage = "https://github.com/fiatjaf/nak";
    license = licenses.unlicense;
    maintainers = [ ];
    mainProgram = "nak";
  };
}
