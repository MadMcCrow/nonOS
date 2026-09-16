# flake part module for building a VM
{
  inputs,
  self,
  ...
}:
let
  vmConfig = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      {
        imports = [ self.nixosModules.default ];
        config = {
          networking.hostName = "image";
          nixpkgs.hostPlatform = "x86_64-linux";
        };
      }
    ];
  };
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages = {
        # inherit (vmConfig.config.system.build) images;
        # default = self.packages.${system}.run-image;
      };
    };
}
