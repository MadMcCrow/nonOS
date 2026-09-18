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
    minimize = lib.mkEnableOption "minimize storage usage by disabling useless derivations" // {
      default = true;
    };
  };
  config = lib.mkIf cfg.minimize {
    # speechd cause massive size
    services.speechd.enable = mkForce false;
    system.etc.overlay.enable = mkDefault true;
    system.tools.nixos-generate-config.enable = mkDefault false;
    boot.loader.grub.enable = mkDefault false;
    environment.defaultPackages = mkDefault [ ];
    documentation.info.enable = mkDefault false;
    documentation.nixos.enable = mkDefault false;
  };
}
