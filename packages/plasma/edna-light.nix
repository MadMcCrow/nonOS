# edna-light.nix
# https://gitlab.com/jomada/Edna-Light
{
  lib,
  stdenvNoCC,
  zstd,
  ...
}:
let
  pname = "Edna-Light";
  sources = import ../_npins;
  pin = sources.${pname};
in
stdenvNoCC.mkDerivation {
  pname = lib.toLower pname;
  version = "main";
  #inherit (pin) version;

  src = pin;

  nativeBuildInputs = [ zstd ];
  unpackPhase = ''
    ls -la  $src
    cat $src/install.sh
    defefsefes
  '';
  installPhase = ''
    mkdir -p $out/share
    cp -r ./usr/share/* $out/share/
  '';
}
