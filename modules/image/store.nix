# store.nix
# /nix/store = overlay(ro squashfs slot, rw btrfs on the data disk)
{
  modConfig,
  mkOptions,
  self,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
let
  roMount = "/nix/.ro-store";
  rwMount = "/nix/.rw-store";
in
{
  options = (with self.lib.options); mkOptions {
    # add options here
  };

  # TODO : auto mount rw store if detected at boot
  # otherwise just bind the ro-store and disable nix daemon
  config = mkIfEnable {
  };
}
