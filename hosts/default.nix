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
  # copy every configuration
  hostConfigs = lib.genAttrs' (inputs.import-tree.leaves ./configurations) (n: v: nameValuePair (import ./names.nix).${lib.removeSuffix ".nix" n} v);
  hostModules = builtins.mapAttrs (n: v: [v {networking.hostName = lib.mkDefault n;}])
in
{
  flake = {
    # expose our profiles
    profiles = import ./profiles args;
    # hosts are exposed directly as output
    hosts = hostModules;
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
