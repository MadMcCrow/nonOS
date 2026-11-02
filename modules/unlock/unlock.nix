# select the pin implementation
{
  mkModule,
  mkOptions,
  meta,
  ...
}:
{
  lib,
  config,
  ...
}:
let
  implementations = ["npins" "nurl" "tack"];
in
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {
    path = mkPathOption "where to store the lock file" "/etc/${meta.name}/${moduleName}"
    implementation = mkEnumOption "How to produce a config path to import" implementations "npins";


    nixpkgs = lib.mkOption {
       description = "How to fetch the nixpkgs sources";
        type = lib.types.either
         # follow official channels, hosted on Amazon servers
          (lib.types.submodule {
            options.channel = mkStrOption "branch to use" "nixos-unstable";
            }
          )
          # download from github servers
          (lib.types.submodule {
            options.url = mkStrOption "nixpkgs git repository url" "https://github.com/nixOS/nixpkgs.git";
            options.branch = mkStrOption "branch to use" "nixos-unstable";
          });
          # default to channels : faster
          default = {
            channel = "nixos-unstable";
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
    ${meta.name}.${moduleName} = builtins.listToAttrs (map (x: lib.nameValuePair x (cfg.implementation == x)) implementations);

    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];

  };
}
