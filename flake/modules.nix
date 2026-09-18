# flake part module for exposing nixosModules
{
  self,
  inputs,
  ...
}:
with builtins;
let
  inherit (inputs.nixpkgs) lib;

  # helper to import each and every module folder in ../modules
  mkMod =
    modulePath:
    let
      moduleName = lib.baseNameOf modulePath;
      meta = import (self + "/lib/meta.nix") { inherit lib; };

      moduleArgs = {
        # provide values and shortcuts
        inherit inputs meta self;
        inherit (meta) name;
        mkPrio = lib.mkOverride 990; # mkDefault but higher priority

        modConfig = config: rec {
          # expose the flake packages :
          ospkgs = self.packages.${config.nixpkgs.hostPlatform.system};
          # expose the enable option
          cfg = config.${meta.name}.${moduleName};
          # add config condition helper
          mkIfEnable = cAttr: lib.mkIf cfg.enable cAttr;
        };

        # set options with the correct path :
        mkOptions = optAttr: {
          options.${meta.name}.${moduleName} = optAttr;
        };
      };
    in
    _: {
      # import apply all the submodules
      imports = map (x: lib.modules.importApply x moduleArgs) (inputs.import-tree.leafs modulePath);
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
  moduleDirs =
    with builtins;
    attrNames (
      lib.filterAttrs (n: v: (match "^[. _].*" n != null) && v == "directory") (
        readDir (self + "/modules")
      )
    );
in
rec {
  flake = {
    nixosModules =
      (builtins.listToAttrs (
        map (x: {
          name = x;
          value = mkMod x;
        }) moduleDirs
      ))
      // {
        default = _: { imports = map mkMod moduleDirs; };
      };
    # evaluate system to get options :
    # nixosModulesOptions = (lib.nixosSystem { modules = [ (import (self + "/checks/minimal.nix") {
    #  nixpkgs = inputs.nixpkgs;
    #  nonOS = self;
    # }) ]; }).options.nonOS;
  };
}
