# flake part module for building test configurations
{
  self,
  inputs,
  ...
}:
let
  # QEMU VM configuration
  mkVM= _ : {
    imports = ["${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"]
    config = {
            virtualisation.memorySize = 4096;
            virtualisation.cores = 4;
          }
    };


  nonOSsystem = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      (self + "/test/configuration.nix")
      mkVM
    ];
    specialArgs = {
      nonOS = self;
    };
  };
in
{
  # expose our configuration
  flake.nixosConfigurations = { inherit nonOSsystem; };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages = {
        image = lib.traceVal nonOSsystem.config.system.build.images;
        # default = self.packages.${system}.run-image;
      };
    };
}
