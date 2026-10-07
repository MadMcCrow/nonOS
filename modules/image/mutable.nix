# mutable.nix
# allow mutable config for the OS
{
  modConfig,
  mkOptions,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    enable = lib.mkEnableOption "configuration of the OS from mutable tools" // {
      default = true;
    };
    # where to store mutable config
    storage.persistDir = lib.mkOption {
      description = "where to keep the persistant config usually defined in /etc.";
      type = lib.types.path;
      default = "/var/persist/etc";
    };

    remoteInterface = {
      enable = lib.mkEnableOption "remote management from Cockpit" // {
        default = true;
      };
      port = lib.mkOption {
        description = "port for the Cockpit webUI";
        default = 457;
        type = lib.types.port;
        example = 4040;
      };
    };
  };
  config = mkIfEnableAnd cfg.enable {
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

    # link all important files for users and hostname
    systemd.tmpfiles.rules = [
      "d ${cfg.storage.persistDir} 0750 root root - -"
    ] ++ lib.flatten (map (x :
      [
      "f  ${cfg.storage.persistDir}/${x} 0750 root root - -"
      "L+ /etc/${x} - - - - ${cfg.storage.persistDir}/${x}"
    ]) [" hostname" "passwd" "group" "shadow"]);

  };
}
