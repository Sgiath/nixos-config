{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "ntm";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "ntm";
    rev = "v${version}";
    hash = "sha256-fQWKxosRJSGyBHaR8n4oVsgp0YdUxd7AjuxEG8c2URs=";
  };

  vendorHash = "sha256-feuNQJUzDsPxrRZ39no+QzPIiAN/uh7Qu2mwu+KC6iw=";

  subPackages = [ "cmd/ntm" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Dicklesworthstone/ntm/internal/cli.Version=${version}"
    "-X github.com/Dicklesworthstone/ntm/internal/cli.BuiltBy=nix"
  ];

  meta = with lib; {
    description = "Named Tmux Manager - Orchestrate AI coding agents in tmux sessions";
    homepage = "https://github.com/Dicklesworthstone/ntm";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "ntm";
  };
}
