# find out why your system closure is so big !
{
  lib,
  writeShellApplication,
  nix,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  shellcheck,
  gnumake,
  mandoc,
  ...
}:
writeShellApplication {
  name = "nix-closure-report";
  runtimeInputs = [
    nix
    coreutils
    gawk
    gnugrep
    gnused
  ];
  text = builtins.readfile ./report.sh;

  meta = {
    mainProgram = "config-report";
    licences = [ lib.licenses.mit ];
    platforms = lib.platforms.all;
  };
}
