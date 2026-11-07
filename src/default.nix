# flake part module for our OS source tree
args@{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      # only expose packages supported on this platform
      packages =
        with self.lib.packages;
        genPkgs {
          inherit pkgs args;
          paths = listNixPkgs ./.;
        };
    };
}
