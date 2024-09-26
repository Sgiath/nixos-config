{
  lib,
  python3Packages,
  ...
}:

python3Packages.buildPythonApplication rec {
  pname = "stt";
  version = "0.1.0";
  format = "other";

  propagatedBuildInputs = [
    python3Packages.faster-whisper
  ];

  # Do direct install
  #
  # Add further lines to `installPhase` to install any extra data files if needed.
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${./stt.py} $out/bin/${pname}
  '';
}
