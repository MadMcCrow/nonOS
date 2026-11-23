# nixpkgs flake for nonOS. not the best thing, see docs/flake.md to understand my disappointment
{
  description = "NonOS is an opinionated OS based on NixOS";

  inputs = {
    # nixpkgs
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

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

    # auto format
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pastry = {
      url = "github:MadMcCrow/pastry";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        };
      };

    #  auto define git hooks
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
      inputs.pre-commit.follows = "git-hooks-nix";
    };
    # better flatpak support
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # just command runner
    just = {
      url = "github:casey/just";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  # shim
  outputs = inputs: import ./flake inputs;
}
