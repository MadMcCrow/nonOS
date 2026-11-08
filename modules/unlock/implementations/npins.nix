# npins.nix
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
  # sync script :
  sync = self.packages.${pkgs.stdenv.hostPlatform.system}.npins-sync;

  # environment variables for running npins-sync
  # (runtimeEnv escapes the values itself)
  envVars = {
    NPINS_SYNC_DIR = toString cfg.path;
    # options are word split by the script
    NPINS_SYNC_OPTIONS = lib.concatStringsSep " " cfg.extraOptions;
    # NPINS_SYNC_FORCE is required for manual operations. it should not be enabled
  }
  // (
    if mod.nixpkgs ? channel then
      { NPINS_SYNC_CHANNEL = mod.nixpkgs.channel; }
    else
      {
        NPINS_SYNC_GIT_URL = mod.nixpkgs.url;
        NPINS_SYNC_GIT_BRANCH = mod.nixpkgs.branch;
      }
  );

  updateNixpkgs = pkgs.writeShellApplication {
    name = mod.update.program.name;
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    runtimeEnv = envVars;
    text = ''
      exec ${sync}/bin/npins-sync
    '';
  };
in
{
  # interface
  options = mkOptions {
    # set automatically by the implementation submodule
    _enable = lib.mkEnableOption "npins implementation for the ${moduleName} module";
    # TODO : make the nix expression that imports the npins sources
    path = mkPathOption "where to store the lock file" "${mod.configDir}/npins";
    extraOptions = lib.mkOption {
      description = ''
        list of options to use when calling `npins`
      '';
      type = with lib.types; listOf str;
      default = [ ];
    };
  };

  #
  config = mkIfEnableAnd cfg._enable {
    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];

    ${meta.name}.${moduleName} = {
      update.program.package = updateNixpkgs;
      system.nixpkgs = "(import ${cfg.path}).nixpkgs";
    };
  };
}
