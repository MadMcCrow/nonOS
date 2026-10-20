# edna-light.nix
# https://gitlab.com/jomada/Edna-Light
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  cmake,
  kdePackages,
  unstableGitUpdater,
  ...
}:
let
  pname = "Edna-Light";
  sources = import ../_npins;
  pin = sources.${pname};
in
stdenvNoCC.mkDerivation {
  pname = lib.toLower pname;
  inherit (pin) version;

  src = pin;

  nativeBuildInputs = [ zstd ];
  unpackPhase = ''
    tar -xf  $src
  '';
  installPhase = ''
    mkdir -p $out/share
    cp -r ./usr/share/* $out/share/
  '';
}
