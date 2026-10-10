# identity.nix
# who is this image, and which version
{
  modConfig,
  mkOptions,
  meta,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  config = mkIfEnable {
    system.image.id = "nonOS";
    # bump on every release : sysupdate compares versions
    system.image.version = lib.mkDefault meta.version;
    boot.loader.grub.enable = false;
  };
}
