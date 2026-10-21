# nixpkgs.nix
# define how nonOS gets its nixpkgs revision.
{
  mkModule,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
let

in
{
  options = mkOptions {
    # allow moving the configuration folder
    dir = mkPathOption "configuration directory" "/etc/${nonOS.name}";
    sources =
  };

  config = mkIfEnable {
    nix = {
      registry.nixpkgs.to = mkIf (cfg.sources != null) {
        type = "path";
        path = cfg.sources;
      };

      nixPath = [
        "nixpkgs=https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs.rev}.tar.gz"
        "nixpkgs=flake:nixpkgs"
      ];

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

    nixpkgs = {
      # help other modules define allowed unfree packages
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config._unfreePackages;
      # this should not be done
      # pkgs = import (import "${cfg._dir}/npins").nixpkgs { };
    };

    system = {
      # we provide nonOS-rebuild, but still need the activation script
      activatable = true;
      autoUpgrade.enable = false; # we do it ourselves
    };
  };
}
