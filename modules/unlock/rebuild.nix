# rebuild and try to apply the new config
# MAYBE : send a message to the user that the system was updated
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
    # TODO : make sure nixOS rebuild use the system.nix entry point and disable the others
    # TODO : make sure the nixOS autoUpgrade service uses our system. make sure the service to update is called first.
  };
}
