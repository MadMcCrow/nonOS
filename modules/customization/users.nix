# users.nix
# to the rest of your config;
# TODO : does this belong here ?
{
  mkModule,
  mkOptions,
  inputs,
  self,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
with builtins;
{
  # interface
  options = mkOptions {
  };

  config = mkIfEnable {
    # enable mutable users if no user is set to admin
    users.mutableUsers = lib.mkDefault (
      !(any (u: u.group == "wheel" || (any (g: g == "wheel") u.extraGroups)) (
        attrValues config.users.users
      ))
    );
  };
}
