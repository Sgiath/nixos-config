{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "lazybeads";
  version = "0-unstable-2025-01-08";

  src = fetchFromGitHub {
    owner = "codegangsta";
    repo = "lazybeads";
    rev = "c8d1bfe8e800082c257274f40f0f799835e155e1";
    hash = "sha256-f+HE73CRFhliPO6qRPmTyNjSpIsfI7qQv31mrhJVOs8=";
  };

  vendorHash = "sha256-TctoBYfA/+IA2Rjfyn/hVM+wdU5FCC5lZn/Dk/UBfw4=";

  # Tests require bd CLI which isn't available during build
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A LazyGit-inspired TUI for managing beads issues";
    homepage = "https://github.com/codegangsta/lazybeads";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lazybeads";
  };
}
