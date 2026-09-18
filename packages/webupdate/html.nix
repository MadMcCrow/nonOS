# the webpage to update the system :
{
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "webupdate";
  version = "0.1";
  src = ./.;
  installPhase = ''
    mkdir -p $out
    cp index.html $out/
    cp style.css $out/
    cp script.js $out/
  '';
}
