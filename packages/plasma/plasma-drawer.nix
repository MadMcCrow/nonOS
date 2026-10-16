# a plasmoid for a GNOME-ish start menu
{
  stdenv,
  libsForQt5,
  zip,
  kdePackages,
  ...
}:
let
  pname = "plasma-drawer";
  sources = import ../_npins;
  pin = sources.${pname};
in
stdenv.mkDerivation {
  inherit pname;
  inherit (pin) version;

  src = pin;

  nativeBuildInputs = [
    libsForQt5.kpackage
    libsForQt5.wrapQtAppsHook
    zip
  ];
  meta = {
    description = "A fullscreen customizable launcher with application directories and krunner-like search for KDE Plasma";
    homepage = "https://api.github.com/${pin.repository.owner}/${pin.repository.repo}";
    inherit (kdePackages.frameworkintegration.meta) platforms;
  };
}
