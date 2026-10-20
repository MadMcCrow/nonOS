# vinyl-theme.nix
# https://github.com/ekaaty/vinyl-theme
{
  lib,
  stdenv,
  cmake,
  kdePackages,
  unstableGitUpdater,
  ...
}:
let
  pname = "vinyl-theme";
  sources = import ../_npins;
  pin = sources.${pname};
in
stdenv.mkDerivation {
  inherit pname;
  inherit (pin) version;

  src = pin;

  buildInputs = with kdePackages; [
    kcmutils
    kconfig
    kdecoration
    kirigami
    kguiaddons
    kcolorscheme
    kcoreaddons
    ki18n
    kiconthemes
    kwindowsystem
    frameworkintegration
  ];

  nativeBuildInputs = [
    cmake
    kdePackages.qttools
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  passthru.updateScript = unstableGitUpdater { };

  meta = with lib; {
    description = "Theme for KDE Plasma";
    mainProgram = "vinyl-settings6";
    homepage = "https://github.com/ekaaty/vinyl-theme";
    license = with licenses; [
      gpl2Plus
      gpl3Plus
    ];
    inherit (kdePackages.plasma-workspace.meta) platforms;
  };
}
