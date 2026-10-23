# nixpkgs
{
  description = "NonOS is an opinionated OS based on NixOS";

  inputs = {
    # nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # flake support
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # allows working without flakes
    flake-compat = {
      url = "https://git.lix.systems/lix-project/flake-compat/archive/main.tar.gz";
      flake = false;
    };

    # import all implicitly
    import-tree.url = "github:denful/import-tree";

    # auto format
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  auto define egit hooks
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };

    # nixos installation
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hardware
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # secureboot support
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.inputs.flake-compat.follows = "flake-compat";
    };
    # impurity has no inputs
    # impurity.url = "github:outfoxxed/impurity.nix";

    # better flatpak support
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # python
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # just command runner
    just = {
      url = "github:casey/just";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      self,
      import-tree,
      treefmt-nix,
      git-hooks-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }: {
        # this is done to avoid spamming until things are stabilized
        systems = [
          "x86_64-linux"
          "aarch64-darwin"
        ]; # lib.systems.flakeExposed;

        # TODO : replace by auto-detect directories
        imports = [
          ./dev # shells and development tools
          # (sources can be in packages or src depending on who develops it)
          # ./docs -> need to implement a man/doc output
          # ./hosts -> TODO
          ./image
          ./iso
          ./lib
          ./modules
          ./packages
          ./src
        ];
      }
    );
}
