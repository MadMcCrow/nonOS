# options.nix
# helper to show the options defined in a module
{
  self,
  lib,
  nixpkgs,
  ...
}:
let
  module = builtins.trace "GOT MODULE" self.nixosModules.default;

  eval = lib.evalModules {
    specialArgs = {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    };
    modules = [
      module
      {
        _module.check = false;
        disabledModules = [
          # avoid issues with
          "${nixpkgs}/nixos/modules/image/repart.nix"
        ];
      }
    ];
  };
in
map (opt: lib.concatStringsSep "." opt.loc) (lib.optionAttrSetToDocList eval.options)
