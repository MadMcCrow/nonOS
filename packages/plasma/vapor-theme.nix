# The KDE Theme of the steam deck.
# TODO :
# switch to aur : https://aur.archlinux.org/plasma6-themes-vapor-steamos.git
# or https://github.com/CachyOS/cachyos-vapor
{
  stdenvNoCC,
  fetchurl,
  zstd,
  kdePackages,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "plasma-vapor-theme";
  version = "0.16-1";
  nativeBuildInputs = [ zstd ];

  src = fetchurl {
    url = "https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-rel/os/x86_64/steamdeck-kde-presets-0.16-1-any.pkg.tar.zst";
    hash = "sha256-3SOzqBUEPWLk7OIv5715whRJa3qmJaMXL1Gf/DKs5bU=";
  };
  unpackPhase = ''
    tar -xf  $src
  '';
  installPhase = ''
    mkdir -p $out/share
    cp -r ./usr/share/* $out/share/
  '';
  meta = {
    inherit (kdePackages.plasma-workspace.meta) platforms;
  };
}
