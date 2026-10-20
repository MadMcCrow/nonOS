# flake part module for packages
# TODO : maybe get rid of the flake-part approach
# RATIONAL : not all packages need to be supported for each platform
args@{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    with lib;
    with builtins;
    let
      # list all directories to parse
      pkgsDir = attrNames (
        filterAttrs (name: type: type == "directory" && !(hasPrefix "_" name)) (readDir ./.)
      );
      # import-tree needs real paths
      pkgsFiles = flatten (map (d: inputs.import-tree.leaves (./. + "/${d}")) pkgsDir);
      # merge into an attributeSet
      allPackages = listToAttrs (
        map (
          x:
          let
            p = pkgs.callPackage x args;
          in
          nameValuePair (getName p) p
        ) pkgsFiles
      );
    in
    {
      # only expose packages supported on this platform
      packages = filterAttrs (_: v: meta.availableOn pkgs.stdenv.hostPlatform v) allPackages;

      # add an update script
      apps.update =
        with pkgs;
        let
          # update pinned sources
          script = writeShellScriptBin "update-pins" ''
            root=$(${getExe git} rev-parse --show-toplevel)
            ${getExe npins} -d "$root/packages/_npins" update
          '';
        in
        {
          type = "app";
          program = "${getExe script}";
        };
    };
}
