# manifest file : ignored by import tree
# but useful for building the module list
{
  lib,
  import-tree,
  nonOS,
  ...
}:
let
  mkMod = dir: (map (x: lib.modules.importApply x (nonOS dir)) (import-tree.leafs dir));
in
{
  #  disks, format, boot, networking, updates
  core = mkMod ./core;
  # desktop environment
  desktop = mkMod ./desktop;
  # setup image
  storage = mkMod ./storage;
}
