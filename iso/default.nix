# iso/flake-part :
# build the live-iso configuration
{
  self,
  lib,
  ...
}:
let
  # live-iso config for each linux system
  iso =
    system:
    lib.nixosSystem {
      inherit system;
      modules = [
        ./config.nix
      ];
      specialArgs.nonOS = self;
    };
in
{
  # expose the defaut
  flake.nixosConfigurations.iso = iso "x86_64-linux";
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.iso = (iso system).config.system.build.isoImage;
    };
}
