# flake part module for exposing nixosModules
{
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
      meta = import (self + "/lib/meta.nix") { inherit lib; };

      moduleArgs =
        path:
        let
          submodule = unsafeDiscardStringContext (lib.removeSuffix ".nix" (lib.baseNameOf path));
        in
        {
          # provide values and shortcuts
          inherit inputs meta self;
          inherit (meta) name;
          mkPrio = lib.mkOverride 990; # mkDefault but higher priority

          modConfig = config: rec {
            # expose the flake packages :
            ospkgs = self.packages.${config.nixpkgs.hostPlatform.system};
            # expose the enable option
            cfg = config.${meta.name}.${moduleName}.${submodule};
            # add config condition helper
            mkIfEnable = cAttr: lib.mkIf cfg.enable cAttr;
            mkIfEnableAnd = cond: cAttr: lib.mkIf (cfg.enable && cond) cAttr;
          };

          # set options with the correct path :
          mkOptions = optAttr: {
            ${meta.name}.${moduleName}.${submodule} = optAttr;
          };
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
