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
  files = inputs.pastry.listImportChildren ./.;
in
{
  # import all
  flake.lib = inputs.pastry.lib // (lib.genAttrs' files (
    x:
    lib.nameValuePair (inputs.pastry.lib.modName x) (import x args)
  ));
}
