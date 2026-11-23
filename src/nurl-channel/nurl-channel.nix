# nurl-channel
# follow channels and git sources, and generate the nurl fetcher files
# NOTE : at runtime, nurl calls `nix` : it must be in PATH.
{
  lib,
  rustPlatform,
  pkg-config,
  openssl,
  libgit2,
  zlib,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "nurl-channel";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    # nurl is a git dependency (fork)
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [
    pkg-config
    openssl
    libgit2
    zlib
  ];

  meta = {
    description = "Follow channels and git sources, and generate nurl fetcher files";
    mainProgram = "nurl-channel";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
