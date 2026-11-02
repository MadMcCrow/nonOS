# tack.nix :
# use tack to pin the sources
{
  mkModule,
  mkOptions,
  meta,
  moduleName,
  self,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
{
  # interface
  options = mkOptions {
    enable = lib.mkEnableOption "tack implementation for ${moduleName}";
    # TODO :
  };

  # WIP
  config = mkIfEnableAnd cfg.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = "tack unlock is not implemented yet";
      } ];
  };
}
