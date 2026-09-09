# nonOS.nix
# helper attrset for modules;
inputs@{
  self,
  lib,
  ...
}:
modulePath:
let
  moduleName = lib.baseNameOf modulePath;
  meta = import ./meta.nix inputs;
in
with builtins;
{
  # provide values and shortcuts
  inherit inputs meta;
  inherit (meta) name;
  mkPrio = lib.mkOverride 990; # mkDefault but higher priority

  modConfig = config: rec{
    # pkgs = self.packages.${config.nixpkgs.hostPlatform.system};
    cfg = config.${meta.name}.${moduleName};
    mkIfEnable = cAttr: lib.mkIf cfg.enable cAttr;
  };

  # set options :
  mkOptions = optAttr: {
    ${meta.name} = {
      enable = lib.mkEnableOption "" // {
        default = true;
      };
      ${moduleName} = {
        enable = lib.mkEnableOption "" // {
          default = true;
        };
      }
      // optAttr;
    };
  };
}
