# npins sync command for updating the system with npins
{
  lib,
  stdenvNoCC,
  npins,
  shellcheck,
  self,
  ...
}:
let
  script = "npins-sync.sh";
in
stdenvNoCC.mkDerivation {
  pname = "npins-sync";
  inherit (self.lib.meta) version;
  src = ./npins-sync;
  patchPhase = ''
    # patch shell
    patchShebangs ${script}
    # patch npins
    substituteInPlace ${script} --replace-fail "NPINS_BIN=\"npins\"" "NPINS_BIN=\"${lib.getExe npins}\""
  '';
  nativeBuildInputs = [ shellcheck ];
  buildInputs = [ npins ];
  checkPhase = "shellcheck ${script}";
  installPhase = ''
    install -Dm755 ${script} $out/bin/npins-sync
  '';
}
