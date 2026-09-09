# nixpkgs.nix
# define how nonOS gets its nixpkgs
{modConfig, mkOptions, ...}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    # global option to allow unfree packages in other modules
    _unfreePackages = with lib; mkOption {
      description = "accepted unfree packages";
      default = [ ];
      type = with types; listOf nonEmptyStr;
    };
    # allow moving the configuration folder
    _dir = with lib; mkOption {
      description = "configuration directory";
      default = "/etc/${nonOS.name}";
      type = types.path;
    };
    sources = with lib; mkOption {
      description = ''
        the npins source of nixpkgs
        use :
              ```
                let sources = import ./npins;
                ...
                nonOS.nixpkgs.sources = sources.nixpkgs;
              ```
        to use the pins nixpkgs
      '';
      type = with types; nullOr path;
      default = null;
    };
  };

  config = mkIfEnable {
    nix = {
      registry.nixpkgs.to = mkIf (cfg.sources != null) {
        type = "path";
        path = cfg.sources;
      };

      nixPath = [
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "/nix/var/nix/profiles/per-user/root/channels"
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
