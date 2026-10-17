# Linux-Arctis-Manager
# a cool app to manage Steelseries headsets
{
  lib,
  pkgs,
  ...
}:
let
  pname = "Linux-Arctis-Manager";
  sources = import ../_npins;
  pin = sources.${pname};
  pythonPkgs = pkgs.python311Packages;
in
pythonPkgs.buildPythonPackage {
  pname = lib.toLower pname;
  inherit (pin) version;
  src = pin;

  pyproject = true;
  build-system = [ pythonPkgs.uv-build ];
  propagatedBuildInputs = with pythonPkgs; [
    uv
    uv-build
    autoflake
  ];

  meta = {
    homepage = "https://api.github.com/${pin.repository.owner}/${pin.repository.repo}";
    description = "A replacement for SteelSeries GG software, to manage your Arctis device on Linux!";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
