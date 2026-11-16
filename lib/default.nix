# flake part module for exposing lib
args@{
  inputs,
  self,
  lib,
  ...
}:
with builtins;
let
  # get all the paths to import (everything but the default)
  files = inputs.import-tree (i: i.matchNot ".*/default.nix") (i: i.leaves (./.));
  # get our tools
  mylib = import ./lib.nix args;
in
{
  # import all
  flake.lib = mylib // (lib.genAttrs' files (
    x:
    lib.nameValuePair (mylib.modName x) (import x args)
  ));
}
