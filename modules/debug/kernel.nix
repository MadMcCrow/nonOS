# root.nix
# Module to set the boot timemout for faster debug
{
  mkModule,
  mkOptions,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
{
  # just add this debug option
  config = mkIfEnable {
    boot.kernelParams = [ "console=ttyS0" ];
  };
}
