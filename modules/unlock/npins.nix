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
    text = ''
      NPINS_DIR=${lib.escapeShellArg (toString cfg.directory)}
      CLEAN_ON_FAILURE="''${CLEAN_ON_FAILURE:-${lib.boolToString cfg.cleanOnFailure}}"

      case "$CLEAN_ON_FAILURE" in
        true|false) ;;
        *)
          echo "Error: CLEAN_ON_FAILURE must be 'true' or 'false'." >&2
          exit 2
          ;;
      esac

      if [ ! -d "$NPINS_DIR" ]; then
        echo "Error: NPINS_DIR is not an existing directory: $NPINS_DIR" >&2
        exit 1
      fi

      init_npins() {
        echo "Initializing npins in $NPINS_DIR..."

        npins ${lib.escapeShellArgs cfg.options} init \
          --bare --directory "$NPINS_DIR" || return $?

        npins ${lib.escapeShellArgs cfg.options} add \
          --directory "$NPINS_DIR" \
          --name nixpkgs \
          ${lib.escapeShellArgs (
            if cfg.nixpkgs ? channel then
              [ "channel" cfg.nixpkgs.channel ]
            else
              [ "git" cfg.nixpkgs.url "--branch" cfg.nixpkgs.branch ]
          )} || return $?

        echo "npins initialization succeeded."
      }

      # Check whether the directory contains any entries, including hidden files.
      is_empty=true
      for entry in "$NPINS_DIR"/* "$NPINS_DIR"/.[!.]* "$NPINS_DIR"/..?*; do
        if [ -e "$entry" ] || [ -L "$entry" ]; then
          is_empty=false
          break
        fi
      done

      if [ "$is_empty" = true ]; then
        init_npins
        exit $?
      fi

      if npins ${lib.escapeShellArgs cfg.options} update --directory "$NPINS_DIR"; then
        echo "npins update succeeded."
      else
        update_status=$?
        echo "npins update failed (exit status $update_status)." >&2

        if [ "$CLEAN_ON_FAILURE" = true ]; then
          echo "Reinitializing $NPINS_DIR..." >&2

          for entry in "$NPINS_DIR"/* "$NPINS_DIR"/.[!.]* "$NPINS_DIR"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            rm -rf "$entry" || exit 1
          done

          init_npins || exit $?
        else
          exit "$update_status"
        fi
      fi
    '';
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
