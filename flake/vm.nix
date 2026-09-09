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
          nonOS = {
            enable = true;
            storage.device = "/dev/nvme0n1";
          };
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
        inherit (vmConfig.config.system.build) image;
        # default = self.packages.${system}.run-image;
      };
    };
}
