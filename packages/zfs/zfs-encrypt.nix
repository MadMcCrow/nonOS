# zfs/zfs-encrypt.nix
# both tpm and fido support for zfs, in one package
inputs@{
  lib,
  symlinkJoin,
  callPackage,
  ...
}:
symlinkJoin {
  name = "zfs-ecrypt";
  paths = map (x: callPackage x inputs) [
    ./fzifdso.nix
    ./tzpfms.nix
  ];
}
