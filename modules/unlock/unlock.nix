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
  implementations =
    with builtins;
    map (mod: unsafeDiscardStringContext (lib.removeSuffix ".nix" (baseNameOf mod))) (
      inputs.import-tree.leaves ./implementations
    );
in
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {
    configDir = mkPathOption "where to store the lock file" "/etc/${meta.name}/${moduleName}";
    nixpkgs = lib.mkOption {
      description = "How to fetch the nixpkgs sources";
      type =
        with lib.types;
        either
          # follow official channels, hosted on Amazon servers
          (submodule {
            options.channel = mkStrOption "branch to use" "nixos-unstable";
          })
          # download from github servers
          (
            submodule {
              options.url = mkStrOption "nixpkgs git repository url" "https://github.com/nixOS/nixpkgs.git";
              options.branch = mkStrOption "branch to use" "nixos-unstable";
            }
          );
      # default to channels : faster
      default = {
        channel = "nixos-unstable";
      };
    };
  };

  config = mkIfEnable {
    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];
    # TODO write the main service and replace it into system.autoUpgrade.
  };
}
