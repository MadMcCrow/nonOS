# flake part central definition
inputs@{
  self,
  nixpkgs,
  import-tree,
  flake-parts,
  ...
}:
let
  inherit (nixpkgs) lib;
  directories =
    root:
    with builtins;
    map (x: "${root}/${x}") (
      attrNames (
        lib.filterAttrs
          (
            n: t:
            t == "directory"
            && ((match "(flake|[._]+.*)" (baseNameOf n)) == null)
            && (pathExists "${root}/${n}/default.nix")
          )
          # list the root of the flake
          (readDir root)
      )
    );
in
(flake-parts.lib.mkFlake { inherit inputs; } (
  { lib, ... }: {
    # this is done to avoid spamming until things are stabilized
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ]; # lib.systems.flakeExposed;

    # autodect importable directories
    imports = directories ../.;
  }
))
// {
  inherit (inputs) nixpkgs;
}
