# pull the update
# We could use either https://github.com/nlewo/comin
{
  mkModule,
  mkOptions,
  meta,
  self,
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
  config = mkIfEnable {
    # TODO : source the local pin into an overlay
    nixpkgs = {

    };
    # TODO : create the service that rebuilds the OS with --impure

    # TODO : manage the installation case :
    # ie. disable sourcing when installing, or at least source a fixed starting point
  };
}
