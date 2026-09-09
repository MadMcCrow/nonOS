# minimal.nix
# optimize images sizes
{modConfig, mkOptions, ...}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  options =
    mkOptions {
      minimize = lib.mkEnableOption "minimize storage usage by disabling useless derivations" // {default = true; };
    };
  config =
  services.speechd.enable = false;
  # Remove perl from activation
  system.etc.overlay.enable = lib.mkDefault true;
  system.tools.nixos-generate-config.enable = lib.mkDefault false;
  boot.loader.grub.enable = lib.mkDefault false;
  environment.defaultPackages = lib.mkDefault [ ];
  documentation.info.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;
};
