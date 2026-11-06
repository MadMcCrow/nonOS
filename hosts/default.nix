# flake part module for hosts
{
  inputs,
  self,
  ...
}:
let
  root = ./.;
  # list every directory that contain configuration.nix
  hosts =  lib.filterAttrs (n: v: lib.pathIsRegularFile v) (lib.genAttrs (n: lib.traceVal "${root}/${n}/configuration.nix") (self.lib.packages.listDir root));

in
{
  flake = {
    inherit hosts;

    nixosConfigurations = mapAttrs (n: v: lib.nixosSystem {
      configuration = hosts;
      specialArgs.${meta.name} = self;
    }) hosts;
  };

}
