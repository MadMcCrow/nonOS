# npins sync command for updating the system with npins
# requires a compiler for building and npins at runtime
{
  lib,
  stdenv,
  npins,
  ...
}:
stdenv.mkDerivation rec {
  pname = "npins-sync";
  version = "0.1";
  buildInputs = [npins];
  src = ./npins-sync;
  installPhase = ''
    mkdir -p $out/bin
    cp ${pname} $out/bin/
  '';
  meta = {
    mainProgram = pname;
  };
}
