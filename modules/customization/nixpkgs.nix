# nixpkgs.nix
# optimization and changes to the default nixpkgs options
{
  mkModule,
  mkOptions,
  self,
  inputs,
  meta,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with self.lib.options;
let
  cfg = config.${meta.name}.nixpkgs;
  inherit (lib) mkDefault mkForce;
in
{
  # we go fully shared
  options.${meta.name}.nixpkgs = {
    # support defining unfree packages
    unfreePackages = mkTypedOption (with types; listOf nonEmptyStr) "accepted unfree packages" [ ];
    # avoid appending the whole nixpkgs sources to the closure
    # (saves around 300MB for images and iso)
    removeSources = mkBoolOption "remove nixpkgs sources from the store/tree closure" true;
  };

  config = lib.mkMerge [
    {
      # default to lix
      nix = lib.mkDefault {
        package = pkgs.lix;

        settings = {
          # keep flake and commands
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          # cache providers
          substituters = [
            "https://nix-community.cachix.org"
            "https://cache.nixos.org/"
            "https://cachix.cachix.org"
            "https://nixpkgs.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
            "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
          ];
        };
      };
      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.unfreePackages;
    }
    (lib.mkIf cfg.removeSources {
      nixpkgs.flake = mkForce {
        source = null;
        setNixPath = false;
        setFlakeRegistry = false;
      };

      # TODO : build from actual input
      nix = {
        nixPath = mkDefault [
          "nixpkgs=https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs.rev}.tar.gz"
        ];
        # TODO : replace with the actual input for repo/owner
        registry.nixpkgs.to = mkDefault {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          rev = inputs.nixpkgs.rev;
        };
      };
    })
  ];
}
