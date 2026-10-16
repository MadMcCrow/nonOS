# config.nix
# allow mutable config for the OS
{
  mkModule,
  mkOptions,
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
  options = mkOptions {
    remoteInterface = {
      enable = mkBoolOption "remote management from Cockpit" true;
      port = mkPortOption "port for the Cockpit webUI" 457;
    };
  };

  config = mkIfEnable {
    # dhcp or hostnamed
    networking = {
      hostName = lib.mkForce "";
      networkmanager.enable = true;
    };

    # make sure things are editable
    users.mutableUsers = true;

    # cockpit config file
    services.cockpit = lib.mkIf cfg.remoteInterface.enable {
      enable = true;
      port = cfg.remoteInterface.port;
    };

    # this is necessary for mutability
    system.etc.overlay.enable = true;
  };
}
