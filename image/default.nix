# flake part module for building test configurations
args@{
  self,
  inputs,
  lib,
  ...
}:
let
  image =
    system:
    lib.nixosSystem {
      inherit system;
      modules = [ ./config.nix ];
      specialArgs.nonOS = self;
    };
in
{
  # expose our configuration
  flake.nixosConfigurations.image = image "x86-64_linux";

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    with pkgs;
    let
      qemu = callPackage ./vm.nix args;
      install = callPackage ./install.nix args;
    in
    lib.mkIf stdenv.hostPlatform.isLinux {
      packages = let
        image-config = (image system);
        in
        {
        image-raw     = image-config.config.system.build.image;
        image-run     = qemu image-config;
        image-install = install image-config;
      };
    };
}
