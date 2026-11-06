# select the pin implementation
{
  mkModule,
  mkOptions,
  meta,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
let
  # generate list of implementations from directory
  implementations = with builtins; map
  (mod: unsafeDiscardStringContext (lib.removeSuffix ".nix" (baseNameOf mod)))
  (inputs.import-tree.leaves ./implementations);
in
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {

    configDir = mkPathOption "where to store the lock file" "/etc/${meta.name}/${moduleName}"
    implementation = mkEnumOption "How to produce a config path to import" implementations "npins";
    update = {
      program = lib.mkOption {
        description = "package to use to update the unlock nixpkgs version";
        type = lib.types.package;
        internal = true;
      };
      name = mkStrOption "name of the unlock/update/rebuild service" "${meta.name}-${moduleName}";
    };

    };
  };

  config = mkIfEnable {

  {
    # we can't use both backend at once.
    # changing backend might cause issues.
    # TODO: add a warning at eval if the backend changes from the currently running OS.
    # TODO: get the list of options from
    assertion = lib.lists.count (lib.trivial.id) (map (x: config.${moduleName}.${x}.enable)
      implementations) == 1;
    message = "only one of tack and npins can be used as a backend for the source pinning";
  }

    # select implementation
    ${meta.name}.${moduleName} = builtins.genAttrs implementations (x: { _enable = cfg.implementation == x; });

    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];


    nixpkgs.overlays = [ overlay ];
  };
}
