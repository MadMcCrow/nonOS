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
      # list all directories to parse
      pkgsDir = attrNames (
                filterAttrs
                (name: type: type == "directory" && (! lib.hasPrefix "_" name ))
                (readDir ./.)
      );
      # now get all the nix files
      pkgsFiles = flatten (map (d: inputs.import-tree.leaves d) pkgsDir);
      # merge into an attributeSet
      allPackages = listToAttrs (map (x: let p = pkgs.callPackage x args; in lib.nameValuePair (lib.getName p) p) pkgsFiles);
    in
    {
      # only expose supported packages :
      packages = filterAttrs (_ :v: isSupported pkgs.lib.meta.availableOn v system) allPackages;
      # add an update script
      apps.update = with pkgs;
        # update pinned sources
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
}
