{
  # auto format
  treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  #  auto define git hooks
  git-hooks-nix = {
    url = "github:cachix/git-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-compat.follows = "flake-compat";
  };


  # just command runner
  just = {
    url = "github:casey/just";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
