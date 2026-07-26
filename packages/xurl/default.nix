{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "xurl";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "xdevplatform";
    repo = "xurl";
    rev = "v${version}";
    hash = "sha256-dwVBzuUhQpfRWFOZOf1DCGNKoetdZlcretnyv9AShbw=";
  };

  vendorHash = "sha256-3yUZZYHcDpCaK55uiVw4X9mxvda9iL+XwPpSXheKOSc=";

  postPatch = ''
    substituteInPlace api/client_test.go \
      --replace-fail 'xurl/dev' 'xurl/${version}'
  '';

  ldflags = [
    "-s"
    "-w"
    "-X github.com/xdevplatform/xurl/version.Version=${version}"
  ];

  meta = with lib; {
    description = "Curl-like CLI tool for the X API";
    homepage = "https://github.com/xdevplatform/xurl";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "xurl";
  };
}
