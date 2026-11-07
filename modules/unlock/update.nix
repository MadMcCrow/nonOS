# update the pins before rebuilding the OS
{
  mkModule,
  mkOptions,
  meta,
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
    program = {
      name = mkStrOption "name for the update package" "${meta.name}-update";
      package = lib.mkOption {
        description = "package to use to update the unlock nixpkgs version";
        type = lib.types.package;
        internal = true;
      };
    };
    implementation = mkEnumOption "How to produce a config path to import" implementations "nurl";
    service.name = mkStrOption "name of the unlock/update/rebuild service" "${meta.name}-${moduleName}";
  };

  config = mkIfEnable {
    assertions = {
      # we can't use multiple backend at once.
      # changing backend might cause issues.
      # MAYBE: add a warning at eval if the backend changes from the currently running OS.
      assertion =
        lib.lists.count lib.trivial.id (map (x: config.${moduleName}.${x}.enable) implementations) == 1;
      message = "only one of tack and npins can be used as a backend for the source pinning";
      # TODO : make sure the version of nixpkgs used in nonOS is never more recent than the version pinned by the system
    };
    # select implementation
    ${meta.name}.${moduleName} = builtins.genAttrs implementations (x: {
      _enable = cfg.implementation == x;
    });

    # TODO : create the service that calls the script to update the pinned version of nixpkgs.

    # TODO : pin/update version of nonOS
  };
}
