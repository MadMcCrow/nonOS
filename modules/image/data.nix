# data.nix
# Autodect partitions like home, ...
{
  modConfig,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with (modConfig config);
let
 #
in
{
  options = with (self.lib.options); mkOptions {
    partitions = lib.mkOption {
      description = "auto detect and mount partitions at boot";
      type = with lib.types; attrsOf ( submodule {
        options = {
          label = mkStrOption "partition label for auto-mount" "";
          mountPoint = mkPathOption "where to auto-mount" "";
        };
      });
      default = {
        "home" = {
          label      = "${meta.name}-home";
          mountPoint = "/home";
        };
      };
    };
  };

  # TODO :
  # if
  config = mkIfEnable {

  };
}
