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
in
{
  # import all
  flake.lib = lib.genAttrs' files (
    mod:
    lib.nameValuePair (unsafeDiscardStringContext (lib.removeSuffix ".nix" (baseNameOf mod))) (
      import mod args
    )
  );
}
