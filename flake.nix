# nixpkgs
{
  description = "NonOS is an opinionated OS based on NixOS";

  inputs = {
    # we let the user override the version of nixpkgs in ./flake
    nixpkgs = {
      type = "indirect";
      id = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs :
    let
      flake = import ./flake;
    in
    inputs.flake-parts.lib.mkFlake { inputs = inputs // flake.inputs; } (
      { lib, ... }: (builtins.removeAttrs flake ["inputs"]));
}
