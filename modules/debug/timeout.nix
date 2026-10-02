# timeout.nix
# Module to set the boot timemout for faster debug
{modConfig, mkOptions, ...} :
{lib, config, ...} :
with (modConfig config);
{
options = mkOptions {
  delay= lib.mkOption {
    description = "delay for timeout, in seconds.";
    type =  lib.types.ints.between 0 60;
    default = 10;
  };
};
  config = mkIfEnable {
    boot = {
      kernelParams = [ "systemd.default_timeout_start_sec=${builtins.toString cfg.delay}" ];
    initrd.systemd.settings.Manager = {
      DefaultTimeoutStartSec = "${builtins.toString cfg.delay}s";
      DefaultTimeoutStopSec = "${builtins.toString cfg.delay}s";
    };
  };
  };
}
