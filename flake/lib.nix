# flake part module for exposing lib
{
  inputs,
  self,
  lib,
  ...
}:
with builtins;
let
  inherit (inputs.nixpkgs) lib;
  mksysPair = mod: {
    name = unsafeDiscardStringContext (baseNameOf (lib.removeSuffix ".nix" mod));
    value = import mod (inputs // { inherit lib; });
  };
in
{
  flake.lib = builtins.listToAttrs (
    inputs.import-tree (i: i.map mksysPair) (i: i.leaves (self + "/lib"))
  );
}
