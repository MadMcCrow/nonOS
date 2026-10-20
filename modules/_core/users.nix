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
    # TODO: create a ssh config option
    ssh4All = {
      enable = lib.mkEnableOption "ssh access for all users";
      passwordless = mkBoolOption "make ssh work only with key";
    };
  }


  config = mkIfEnable {
# enable mutable users if no user is set to admin
 mutableUsers = lib.mkDefault
   !(any (u: u.group == "wheel" || (any (g: g == "wheel") u.extraGroups)) (
     attrValues config.users.users
   ));

   # enable ssh for all users
   services.openssh = lib.mkIf cfg.ssh4All {
       enable = true;
       # ports = [ 8323 ]; # set it in your config
       settings = {
         PasswordAuthentication = lib.mkDefault true;
         KbdInteractiveAuthentication = lib.mkDefault false;
         PermitRootLogin = "no";
         AllowUsers = attrNames config.users.users;
       };
     };
   };
}
