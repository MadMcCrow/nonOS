# flake part module for building test configurations
{
  self,
  inputs,
  ...
}:
with builtins;
with inputs.nixpkgs.lib;
let
  nonOSsystem = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
          self.nixosModules.default
          {
            networking.hostName = "minimal";
            nixpkgs.hostPlatform = "x86_64-linux";
            nonOS = {
              enable = true;
              image.device = "/dev/nvme0n1";
            };
            boot.loader.grub.enable = false;
            services.getty.autologinUser = "root";
            users.users.root.initialPassword = "";
          }];
    };
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
        inherit (nonOSsystem.config.system.build) image;
        # default = self.packages.${system}.run-image;
      };
    };
}
