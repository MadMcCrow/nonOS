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
    let
      # list all directories to parse (ignore the ones starting with "_")
      pkgsDir = builtins.attrNames (
        lib.filterAttrs (name: type: type == "directory" && !(lib.hasPrefix "_" name)) (
          builtins.readDir ./.
        )
      );
      # now get all the nix files (import-tree needs real paths, not strings)
      pkgsFiles = lib.flatten (map (d: inputs.import-tree.leaves (./. + "/${d}")) pkgsDir);
      # merge into an attributeSet
      allPackages = builtins.listToAttrs (
        map (
          x:
          let
            p = pkgs.callPackage x args;
          in
          lib.nameValuePair (lib.getName p) p
        ) pkgsFiles
      );
    in
    {
      # only expose packages supported on this platform
      packages = lib.filterAttrs (_: v: lib.meta.availableOn pkgs.stdenv.hostPlatform v) allPackages;

      # add an update script
      apps.update =
        with pkgs;
        let
          # update pinned sources
          script = writeShellScriptBin "update-pins" ''
            root=$(${lib.getExe git} rev-parse --show-toplevel)
            ${lib.getExe npins} -d "$root/packages/_npins" update
          '';
        in
        {
          type = "app";
          program = "${lib.getExe script}";
        };
    };
}
