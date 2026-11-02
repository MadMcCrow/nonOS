# nurl.nix
# use nurl to generate the nixpkgs pin
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
    enable = lib.mkEnableOption "nurl implementation for ${moduleName}";
    # TODO :
  };

  # WIP
  config = mkIfEnableAnd cfg.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = "nurl unlock is not implemented yet";
      } ];
  };
}
