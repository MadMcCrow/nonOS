# locale.nix
# this is a French project
{
  mkModule,
  mkOptions,
  meta,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
{
  config = mkIfEnable {
    time.timeZone = "Europe/Paris";
  };
}
