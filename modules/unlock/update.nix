# update.nix
# update the pinned nixpkgs. the rebuild itself is done by system.autoUpgrade (see rebuild.nix)
{
  mkModule,
  mkOptions,
  meta,
  moduleName,
  self,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # one backend per file in ./implementations
  implementations = map (
    file: builtins.unsafeDiscardStringContext (lib.removeSuffix ".nix" (baseNameOf file))
  ) (inputs.import-tree.leaves ./implementations);
in
{
  options = mkOptions {
    program = {
      name = mkStrOption "name for the update package" "${meta.name}-update";
      package = mkPkgOption "package to use to update the unlock nixpkgs version" null;
    };
    implementation = mkEnumOption "How to produce a config path to import" implementations "nurl";
    service.name = mkStrOption "name of the service that updates the pin before nixos-upgrade runs" "${meta.name}-${moduleName}";
  };

  config = mkIfEnable {
    assertions = [
      {
        # we can't use multiple backend at once.
        # changing backend might cause issues.
        # MAYBE: add a warning at eval if the backend changes from the currently running OS.
        assertion = lib.count lib.id (map (x: mod.${x}._enable) implementations) == 1;
        message = "only one of ${lib.concatStringsSep ", " implementations} can be used as a backend for the source pinning";
      }
      # TODO : make sure the version of nonOS nixpkgs is never more recent than the version pinned by the system
      #        (to be discussed)
    ];

    # select implementation
    ${meta.name}.${moduleName} = lib.genAttrs implementations (x: {
      enable = cfg.implementation == x;
    });

    # runs the update program. started by nixos-upgrade (see rebuild.nix)
    systemd.services.${cfg.service.name} = {
      description = "update the pinned nixpkgs";
      restartIfChanged = false;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe cfg.program.package;
      };
    };
    # add to the packages to run manually if necessary
    environment.systemPackages = [ cfg.program.package ];
  };
}
