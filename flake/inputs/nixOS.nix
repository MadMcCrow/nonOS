{

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
}
