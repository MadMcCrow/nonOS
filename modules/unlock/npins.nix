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
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # base name for the services and scripts
  serviceName = "${meta.name}-${moduleName}";

  # sync script :
  script = self.packages.${pkgs.stdenv.hostPlatform.system}.npins-sync;

  # shortcut
  sh = lib.escapeShellArg;

  # environment variables for running npins-sync
  envVars = lib.mkMerge [{
    NPINS_SYNC_DIR = sh cfg.path;
    NPINS_SYNC_OPTIONS = lib.strings.concatMapStringsSep " " sh cfg.extraOptions;
    # NPINS_SYNC_FORCE  = "0";  # force is requiered for manual operations.
    # it should not be enabled
  }
  (lib.mkIf (mod.nixpkgs ? "channel") {
     NPINS_SYNC_CHANNEL = sh mod.nixpkgs.channel;
  })
  (lib.mkIf (mod.nixpkgs ? "url") {
      NPINS_SYNC_GIT_URL = sh mod.nixpkgs.url;
      NPINS_SYNC_GIT_BRANCH = sh mod.nixpkgs.branch;
  })
  ];

in
{
  # interface
  options = mkOptions {
    # set automatically by the implementation submodule
    enabled = lib.mkEnableOption "npins implementation for the ${moduleName} module";
    # TODO : make the nix expression that imports the npins sources
    path = mkPathOption "where to store the lock file" "${mod.path}/npins";
    extraOptions = lib.mkOption {
       description = ''
         list of options to use when calling `npins`
         '';
       type = with lib.types; listOf str;
       example = [ "--max-concurrent-downloads $(${coreutils}/bin/nproc)" ];
       default = [];
     };
  };

  #
  config = mkIfEnableAnd cfg.enable {
    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];

    systemd.services."${serviceName}-npins" = {
        description = "npins sync for the ${moduleName} module";
        # TODO : maybe use some other target ?
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = envVars;
        # TODO : change this
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe script;
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # TODO : either add script and envVars to environment
      # and let the user call it manually. or wrap it with
      # force set to true to allow for repairs.
  };
}
