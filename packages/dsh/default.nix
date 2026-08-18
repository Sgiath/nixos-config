{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  runCommand,
}:

let
  pname = "dsh";
  version = "0.1.0-rc.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha256-L48Ldj1hGsU296lBHuQ8CvwGfBuHMsMQLATb45i8rMU=";
  };

  srcWithLock = runCommand "${pname}-source" { } ''
    mkdir -p $out
    tar -xzf ${src} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit pname version;
  src = srcWithLock;

  npmDepsHash = "sha256-Y+Y1f1V7+1sXkezKAeqEOW8GZeScERo/+gWXU4Qjqho=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    rm $out/bin/dsh
    makeWrapper ${lib.getExe nodejs} $out/bin/dsh \
      --argv0 dsh \
      --add-flags "--expose-internals" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  meta = {
    description = "Open-source agent harness developed by DeepSeek AI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
}
