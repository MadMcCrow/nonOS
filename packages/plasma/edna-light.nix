# edna-light.nix
# https://gitlab.com/jomada/Edna-Light
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  kdePackages,
  unstableGitUpdater,
  ...
}:
let
  pname = "edna-light";
  sources = import ../_npins;
  pin = sources.${pname};
in
stdenvNoCC.mkDerivation {
  inherit pname;
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
