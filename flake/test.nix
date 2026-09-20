# flake part module for building test configurations
{
  self,
  inputs,
  ...
}:
let
  nonOSsystem = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ (self + "/test/configuration.nix") ];
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
        image = lib.traceVal nonOSsystem.config.system.build.image;
        # default = self.packages.${system}.run-image;
      };
    };
}
