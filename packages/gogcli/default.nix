{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "gogcli";
  version = "0.35.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-KEytK68g0+MqpcY/R9Wr89tJB7EG6wnmKQAqYWZ/VJU=";
  };

  vendorHash = "sha256-F1D3ax+xiTlhsYLgoe/K8x2VQKG9iHZ5FNJJ9YDkEV0=";

  env.CGO_ENABLED = 0;

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steipete/gogcli/internal/cmd.version=v${version}"
    "-X github.com/steipete/gogcli/internal/cmd.commit=nix"
    "-X github.com/steipete/gogcli/internal/cmd.date=1970-01-01T00:00:00Z"
  ];

  meta = with lib; {
    description = "Google Suite CLI: Gmail, GCal, GDrive, GContacts";
    homepage = "https://github.com/steipete/gogcli";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "gog";
  };
}
