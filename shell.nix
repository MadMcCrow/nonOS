# shell.nix
# give the default dev-shell for systems without flakes
{
  pkgs ? import <nixpkgs> { },
}:
(import ./flake/compat.nix).outputs.devShells.${pkgs.stdenv.hostPlatform.system}.default
