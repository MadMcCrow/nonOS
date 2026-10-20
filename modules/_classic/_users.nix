# users.nix
# offer the ssh4all option and sets mutable users according
# to the rest of your config;
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
{
  # interface
  options = mkOptions {
  };

  config = mkIfEnable {
    # enable mutable users if no user is set to admin
    mutableUsers = lib.mkDefault (
      !(any (u: u.group == "wheel" || (any (g: g == "wheel") u.extraGroups)) (
        attrValues config.users.users
      ))
    );
  };
}
