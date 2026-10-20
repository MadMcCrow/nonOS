# apps.nix
#  add common apps configured through nixpkgs
#  this can be less interesting if you're commited to flatpaks
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
  options = mkOptions {
    # default to true
    enable = lib.mkEnableOption "common desktop apps through nixpkgs";
  };

  # implementation
  config = mkIfEnableAnd cfg.enable {
    # web browser
    programs.firefox.enable = true;
  };
}
