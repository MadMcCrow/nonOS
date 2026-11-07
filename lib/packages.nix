# helper functions for often used patterns in flake part modules
{
  inputs,
  lib,
  ...
}:
rec {
  listDir =
    dir:
    builtins.attrNames (
      lib.filterAttrs (n: t: t == "directory" && !(lib.hasPrefix "_" n)) (builtins.readDir dir)
    );

  # import-tree needs real paths
  listNixPkgs =
    root: lib.flatten (map (d: inputs.import-tree.leaves (root + "/${d}")) (listDir root));

  # make an attributeSet of packages by callPackage paths
  genPkgs =
    {
      pkgs,
      paths,
      args,
    }:
    # turn into an attrset
    lib.genAttrs'
      # filter available (maybe remove the parameter)
      (builtins.filter (p: lib.meta.availableOn pkgs.stdenv.hostPlatform p)
        # import packages
        (map (x: pkgs.callPackage x args) paths)
      )
      (p: lib.nameValuePair (lib.getName p) p);
}
