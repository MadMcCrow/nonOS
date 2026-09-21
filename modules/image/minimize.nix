# minimal.nix
# optimize images sizes
{
  modConfig,
  mkOptions,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    enable = lib.mkEnableOption "minimize storage usage by disabling useless derivations" // {
      default = true;
    };
  };
  config = mkIfEnableAnd cfg.enable (
    with lib;
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
  );
}
