# zfs/zfs-encrypt.nix
# both tpm and fido support for zfs, in one package
inputs@{
  lib,
  symlinkJoin,
  callPackage,
  ...
}:
with lib;
let
  packages = map (x: callPackage x inputs) [
    ./fzifdso.nix
    ./tzpfms.nix
  ];
in
symlinkJoin {
  name = "zfs-encrypt";
  paths = packages;
  version =
    with builtins;
    head (lib.sort (a: b: compareVersions a b > 0) (map (pkg: pkg.version) packages));
}
