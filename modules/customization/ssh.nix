# ssh.nix
# global ssh options for easier configuration
{
  mkModule,
  mkOptions,
  self,
  inputs,
  meta,
  ...
}:
{
  lib,
  config,
  ...
}:
with self.lib.options;
let
  inherit (lib) mkDefault;
  cfg = config.${meta.name}.ssh;
in
{
  options.${meta.name}.ssh = {
    ssh4All = {
      enable = lib.mkEnableOption "ssh access for all users";
      passwordless = mkBoolOption "make ssh work only with key" false;
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.ssh4All.enable {
      # enable ssh for all users
      services.openssh = {
        enable = mkDefault true;
        # ports = [ 8323 ]; # set it in your config
        settings = {
          PasswordAuthentication = mkDefault (!cfg.ssh4All.passwordless);
          KbdInteractiveAuthentication = mkDefault false;
          PermitRootLogin = "no";
          AllowUsers = attrNames config.users.users;
        };
      };
    })
  ];
}
