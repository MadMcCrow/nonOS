# flake part module for building test configurations
{
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
      packages = rec {
        image-raw = (image system).config.system.build.image;
        image-run = qemu image-raw;
        image-install = install image-raw;
      };
    };
}
