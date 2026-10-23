# flake part module for exposing nixosModules
args@{
  self,
  inputs,
  ...
}:
with builtins;
let
  inherit (inputs.nixpkgs) lib;

  rootdir = self + "/modules";

  # helper to import each and every module folder in ../modules
  mkMod =
    modulePath:
    let
      moduleName = unsafeDiscardStringContext (lib.baseNameOf modulePath);
      meta = import (self + "/lib/meta.nix") args;

      moduleArgs =
        path:
        let
          curr = unsafeDiscardStringContext (lib.removeSuffix ".nix" (lib.baseNameOf path));
          subModPath = [
            meta.name
            moduleName
          ]
          ++ (lib.optional (curr != moduleName) curr);
        in
        {
          # provide values and shortcuts
          inherit inputs meta self moduleName;
          inherit (meta) name;
          mkPrio = lib.mkOverride 990; # mkDefault but higher priority

          # helper for building modules
          mkModule =
            config:
            let
              mod = config.${meta.name}.${moduleName};
              cfg = lib.attrByPath subModPath { } config;
            in
            {
              # expose the flake packages :
              ospkgs = self.packages.${config.nixpkgs.hostPlatform.system};

              # expose the module configuration :
              inherit mod cfg;

              # add config condition helper
              mkIfEnable = cAttr: lib.mkIf mod.enable cAttr;
              mkIfEnableAnd = cond: cAttr: lib.mkIf (mod.enable && cond) cAttr;
            };
          # helper for options
          mkOptions = optAttr: lib.setAttrByPath subModPath optAttr;
        };
    in
    _: {
      # import apply all the submodules
      imports = map (x: lib.modules.importApply x (moduleArgs x)) (inputs.import-tree.leaves modulePath);
      # Add the root option for the module
      options.${meta.name}.${moduleName} = {
        enable = lib.mkEnableOption moduleName // {
          default = true;
        };
      };
    };

  # TODO : add this option
  #${meta.name}.enable = lib.mkEnableOption ${meta.name} // {
  #    default = true;
  #
  #  };
  modules =
    with builtins;
    mapAttrs (n: v: mkMod "${rootdir}/${n}") (
      lib.filterAttrs (n: v: (match "^[. _].*" n == null) && v == "directory") (readDir rootdir)
    );
in
rec {
  flake = {
    nixosModules = modules // {
      default = _: { imports = builtins.attrValues modules; };
    };
    # evaluate system to get options :
    # nixosModulesOptions = (lib.nixosSystem { modules = [ (import (self + "/checks/minimal.nix") {
    #  nixpkgs = inputs.nixpkgs;
    #  nonOS = self;
    # }) ]; }).options.nonOS;
  };
}
