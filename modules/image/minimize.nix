# minimal.nix
# optimize images sizes
{
  mkModule,
  mkOptions,
  self,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {
    enable = mkBoolOption "minimize storage usage by disabling useless derivations" true;
    excludeSources = mkBoolOption "remove nixpkgs sources from the closure" true;
  };
  config =  with lib; mkIfEnable (
    mkMerge [
      (mkIf cfg.enable
        {
          # basically :
          # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/image-based-appliance.nix

          # The system cannot be rebuilt.
          nix.enable = mkDefault false;
          system.switch.enable = mkForce false;
          users.mutableUsers = mkDefault false;

          # The system avoids interpreters as much
          # as possible to reduce its attack surface
          boot.initrd.systemd.enable = mkDefault true;
          networking.useNetworkd = mkDefault true;

          # speechd cause massive size
          services.speechd.enable = mkForce false;
          system.etc.overlay.enable = mkDefault true;
          system.tools.nixos-generate-config.enable = mkDefault false;
          boot.loader.grub.enable = mkDefault false;
          environment.defaultPackages = mkDefault [ ];
          documentation.info.enable = mkDefault false;
          documentation.nixos.enable = mkDefault false;
        }
      )
      (lib.mkIf cfg.excludeSources {
        # avoid appending the whole nixpkgs sources to the closure
        # saves around 300MB
        nixpkgs.flake = mkForce {
          source = null;
          setNixPath = false;
          setFlakeRegistry = false;
        };
        nix = mkDefault {
          # TODO : build from actual input
          nixPath = [
            "nixpkgs=https://github.com/NixOS/nixpkgs/archive/${inputs.nixpkgs.rev}.tar.gz"
          ];
          # TODO : replace with the actual input for repo/owner
          registry.nixpkgs.to = lib.mkDefault {
            type = "github";
            owner = "NixOS";
            repo = "nixpkgs";
            rev = inputs.nixpkgs.rev;
          };
        };
      })
    ]
  );
}
