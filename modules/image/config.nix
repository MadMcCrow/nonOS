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
    initialPassword = mkBoolOption "set root initial password" true;
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
    users.users = lib.mkIf cfg.initialPassword {
      root.initialHashedPassword = "$y$j9T$efeFSSCdXT41oO/YqlvSX.$61j5A7D9GxkpWUJREaWCAtXke9.rnrDRbH6YoLyXJH4";
    };

    # cockpit config file
    services.cockpit = lib.mkIf cfg.remoteInterface.enable {
      enable = true;
      port = cfg.remoteInterface.port;
    };

    # this is necessary for mutability
    system.etc.overlay.enable = true;
  };
}
