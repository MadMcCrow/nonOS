# flake part module for hosts
{
  inputs,
  self,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  # list every directory that contain configuration.nix
  hosts = lib.filterAttrs (n: v: lib.pathIsRegularFile v) (
    lib.mapAttrs (n: k: "${./.}/${n}/configuration.nix") (builtins.readDir ./.)
  );
in
{
  flake = {
    # hosts are exposed directly as output
    inherit hosts;
    # and as built configuration
    nixosConfigurations = lib.mapAttrs (
      n: v:
      lib.nixosSystem {
        configuration = hosts;
        specialArgs.${self.lib.meta.name} = self;
      }
    ) hosts;
  };
}
