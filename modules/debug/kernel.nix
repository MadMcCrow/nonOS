# root.nix
# Module to set the boot timemout for faster debug
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
  # just add this debug option
  config = mkIfEnable {
    boot.kernelParams = [ "console=ttyS0" ];
  };
}
