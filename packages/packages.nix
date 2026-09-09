# flake part module for dev shells
{
  inputs,
  self,
  ...
}:
let
  collect =
    pkgs:
    builtins.listToAttrs (
      inputs.import-tree (
        i:
        i.map (
          x:
          let
            p = pkgs.callPackage x inputs;
          in
          pkgs.lib.nameValuePair (pkgs.lib.getName p) p
        )
      ) (i: i.leafs (self + "/packages"))
    );
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      # import everything in the `packages` folder, based on its path
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (collect pkgs);
    };
}
