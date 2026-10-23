# flake part module for our OS source tree
args@{
  inputs,
  self,
  ...
}:
let
# our OS packages
pkgsFiles = [
  ./npins-sync.nix
  ./web-update.nix
];
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    with lib;
    with builtins;
    {
      # only expose packages supported on this platform
      packages = filterAttrs (_: v: meta.availableOn pkgs.stdenv.hostPlatform v) (listToAttrs (
        map (
          x:
          let
            p = pkgs.callPackage x args;
          in
          nameValuePair (getName p) p
        ) pkgsFiles));
    };
}
