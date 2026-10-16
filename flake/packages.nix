# flake part module for dev shells
# TODO : maybe get rid of the flake-part approach
# RATIONAL : not all packages need to be supported for each platform
args@{
  inputs,
  self,
  ...
}:
with builtins;
let
  inherit (inputs.nixpkgs) lib;
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      allPackages = map (x: pkgs.callPackage x args) (inputs.import-tree.leaves (self + "/packages"));
      # supported is explicit
      isSupported = pkg: elem pkgs.stdenv.hostPlatform.system pkg.meta.platforms;
    in
    {
      # import everything in the `packages` folder, based on its path
      packages = listToAttrs (
        map (p: lib.nameValuePair (lib.getName p) p) (filter isSupported allPackages)
      );

      apps = with pkgs; {
        # update pinned sources
        update =
          let
            script = writeShellScriptBin "update-pins"
            ''
              root=$(${lib.getExe git} rev-parse --show-toplevel)
              ${lib.getExe npins} -d "$root/packages/_npins" update;
            '';
          in
          {
            type = "app";
            program = "${lib.getExe script}";
          };
      };
    };
}
