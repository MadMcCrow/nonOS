# npins sync command for updating the system with npins
{
  lib,
  rustPlatform,
  npins,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "npins-sync";
  version = "0.1";
  src = ./npins-sync;

  # no external crates : the lock file only lists this package
  cargoLock.lockFile = ./npins-sync/Cargo.lock;

  env.NPINS_BIN = lib.getExe npins;

  meta.mainProgram = "npins-sync";
}
