# flake part module for hosts
# This is dogfooding (or catfooding if like me you prefer cats)
# I'm using my own "distro" (for lack of a better term) on my own machine
args@{
  inputs,
  self,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  # attrset of every configurations
  configs = builtins.listToAttrs (map (x : lib.nameValuePair (self.lib.modName x) x) (inputs.import-tree.leaves ./configurations));
  # rename them with the naming scheme
  hosts = lib.mapAttrs' (
          n: v:
          lib.nameValuePair (import ./names.nix).${n}
          [v {networking.hostName = lib.mkDefault n;}]
  ) configs;
in
{
  flake = {
    # expose our profiles
    profiles = import ./profiles args;
    # hosts are exposed directly as output
    inherit hosts;
    # and as built configuration
    nixosConfigurations = lib.mapAttrs (
    n: v:
      lib.nixosSystem {
        # not really a good idea, but allows installing same host
        # on different machines
        platform = builtins.currentSystem;
        modules = [ hosts ];
        specialArgs.${self.lib.meta.name} = self;
      }
    ) hosts;
  };
}
