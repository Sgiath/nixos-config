{
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "nordic-gtk-theme";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Nordic";
    rev = "v2.2.0";
    hash = "sha256-wTWHdao/1RLqUmqh/9gEyhERGymFWHqiC97JD28LSgk=";
  };

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/themes/Nordic"
    mkdir -p "$themeDir"
    cp -r gtk-3.0 gtk-4.0 index.theme "$themeDir/"

    runHook postInstall
  '';
}
