# pin.nix
# define where and how the pin get updated
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
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # base name for the services and scripts
  basename = "${meta.name}-${moduleName}";

  # sync process :
  # init the local sources and or
  script = pkgs.writeShellApplication {
    name = "${basename}-sync-npins";
    runtimeInputs = [ pkgs.npins ];

    # TODO : replace by a
    text = "";

  };
in
{

  #
  options = mkOptions {
    path = mkPathOption "where to store the lock file" "/etc/${meta.name}/${moduleName}/npins";
    options = lib.mkOption {
       description = "list of options to use when calling `npins`"l;
       type = with lib.types; listOf str;
       default =  [ "--max-concurrent-downloads $(${coreutils}/bin/nproc)" ];
     };
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

  #
  config = mkIfEnable {
    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];
    services."${name}-sync" = {

    }
  };
}
