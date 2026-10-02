{
  modConfig,
  mkOptions,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  # options = mkOptions { };
  config = mkIfEnable {
    system.image.id = "nonOS";
    # make sure not to use grub
    boot.loader.grub.enable = false;
  };
}
