{
  fetchFromGitHub,
  lib,
  python313Packages,
}:

let
  grammar =
    package:
    package.overrideAttrs (_: {
      dontCheckPythonMetadata = true;
    });
in
python313Packages.buildPythonApplication rec {
  pname = "graphify";
  version = "0.9.39";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Graphify-Labs";
    repo = "graphify";
    tag = "v${version}";
    hash = "sha256-KxmWYGggwthWGWlrXt40YcMO5eYwiDhz2W0yx8NG4I4=";
  };

  build-system = [ python313Packages.setuptools ];

  dependencies =
    with python313Packages;
    [
      networkx
      numpy
      rapidfuzz
      tree-sitter
    ]
    ++ (with tree-sitter-grammars; [
      (grammar tree-sitter-bash)
      (grammar tree-sitter-c)
      (grammar tree-sitter-c-sharp)
      (grammar tree-sitter-cpp)
      (grammar tree-sitter-elixir)
      (grammar tree-sitter-fortran)
      (grammar tree-sitter-go)
      (grammar tree-sitter-groovy)
      (grammar tree-sitter-java)
      (grammar tree-sitter-javascript)
      (grammar tree-sitter-json)
      (grammar tree-sitter-julia)
      (grammar tree-sitter-kotlin)
      (grammar tree-sitter-lua)
      (grammar tree-sitter-objc)
      (grammar tree-sitter-php)
      (grammar tree-sitter-powershell)
      (grammar tree-sitter-python)
      (grammar tree-sitter-ruby)
      (grammar tree-sitter-rust)
      (grammar tree-sitter-scala)
      (grammar tree-sitter-swift)
      (grammar tree-sitter-typescript)
      (grammar tree-sitter-verilog)
      (grammar tree-sitter-zig)
    ]);

  pythonImportsCheck = [ "graphify" ];
  pythonRelaxDeps = [
    "tree-sitter-fortran"
    "tree-sitter-groovy"
    "tree-sitter-julia"
    "tree-sitter-kotlin"
  ];
  dontUsePythonRuntimeDepsCheck = true;

  meta = {
    description = "Turn code, documents, and media into a queryable knowledge graph";
    homepage = "https://github.com/Graphify-Labs/graphify";
    changelog = "https://github.com/Graphify-Labs/graphify/blob/v${version}/CHANGELOG.md";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "graphify";
  };
}
