# store.nix
# /nix/store = overlay(ro squashfs slot, rw fs on the data disk)
# Without the rw device, /nix/store is the ro slot and nix-daemon is down.
# When the rw device appears, the overlay is mounted and nix-daemon starts.
# When it disappears, everything is torn down in reverse order.
# With `enable = false`, only the ro slot is used : no overlay, no rw device.
{
  mkModule,
  mkOptions,
  self,
  meta,
  ...
}:
{
  lib,
  pkgs,
  config,
  utils,
  ...
}:
with (mkModule config);
let
  # constants. The ro slot is mounted here by image.nix : keep in sync.
  roMount = "/nix/.ro-store";
  storePath = "/nix/store";
  dbLink = "/nix/var/nix/db";

  # the underlying device, autodetected by label
  device = "/dev/disk/by-partlabel/${cfg.device.label}";

  # the .device unit systemd creates when udev reports the rw device
  devUnit = "${utils.escapeSystemdPath device}.device";

  # mount and unmount logic, in one script :
  #   nix-store-rw up    -> mount rw device, then the overlay
  #   nix-store-rw down  -> unmount overlay, then rw device (busy-aware)
  nix-store-rw = pkgs.writeShellApplication {
    name = "nix-store-rw";
    runtimeInputs = with pkgs; [
      util-linux
      coreutils
      psmisc
    ];
    # runtimeEnv is already shell-escaped by nixpkgs
    runtimeEnv = {
      RO = roMount;
      STORE = storePath;
      RW = cfg.device.mountPoint;
      RW_DEVICE = device;
      RW_FSTYPE = cfg.device.fsType;
      RW_OPTIONS = lib.concatStringsSep "," cfg.device.options;
      BUSY_TIMEOUT = toString cfg.errors.busy.timeout;
      BUSY_FALLBACK = cfg.errors.busy.fallback;
    };
    text = ''
      lazy=0

      die() {
        echo "nix-store-rw: $*" >&2
        exit 1
      }

      # the store is always a mountpoint (ro bind mount at boot).
      # the overlay is stacked on top of it.
      # -U : only look at the top-most mount.
      overlay_mounted() {
        local fs
        fs=$(findmnt -n -l -U -M "$STORE" -o FSTYPE) || return 1
        [[ "$fs" == overlay ]]
      }

      rw_is_mounted() { mountpoint -q "$RW"; }

      has_option() {
        local opts=$1 expected=$2 item
        local -a fields=()
        IFS=, read -r -a fields <<< "$opts"

        for item in "''${fields[@]}"; do
          [[ "$item" == "$expected" ]] && return 0
        done
        return 1
      }

      overlay_matches() {
        local opts

        overlay_mounted || return 1

        opts=$(findmnt -n -l -U -M "$STORE" -o FS-OPTIONS) || return 1
        has_option "$opts" "lowerdir=$RO" &&
          has_option "$opts" "upperdir=$RW/upper" &&
          has_option "$opts" "workdir=$RW/work"
      }

      rw_matches() {
        local fs mounted_dev expected_dev

        [[ -b "$RW_DEVICE" ]] || return 1

        if [[ "$RW_FSTYPE" != auto ]]; then
          fs=$(findmnt -n -l -U -M "$RW" -o FSTYPE) || return 1
          [[ "$fs" == "$RW_FSTYPE" ]] || return 1
        fi

        mounted_dev=$(findmnt -n -l -U -M "$RW" -o MAJ:MIN) || return 1
        expected_dev=$(lsblk -dnro MAJ:MIN "$RW_DEVICE") || return 1

        [[ -n "$expected_dev" && "$mounted_dev" == "$expected_dev" ]]
      }

      release() {
        local target=$1 check=$2 deadline=$((SECONDS + BUSY_TIMEOUT))

        while "$check"; do
          if (( lazy )); then
            umount -l "$target" || die "lazy unmount failed: $target"
            return
          fi

          if umount "$target" 2>/dev/null; then
            continue
          fi

          if (( SECONDS < deadline )); then
            sleep 1
            continue
          fi

          fuser -vm "$target" >&2 || true

          [[ "$BUSY_FALLBACK" == lazy ]] ||
            die "$target still busy after $BUSY_TIMEOUT seconds"

          echo "nix-store-rw: $target still busy; lazy detach" >&2
          umount -l "$target" || die "lazy unmount failed: $target"
          lazy=1
          break
        done
      }

      up() {
        [[ -d "$RO" && -d "$STORE" ]] ||
          die "lower directory or store mountpoint does not exist"
        [[ -b "$RW_DEVICE" ]] ||
          die "not a block device: $RW_DEVICE"

        if overlay_mounted; then
          overlay_matches ||
            die "$STORE has an overlay, but not the expected one"
        fi

        if rw_is_mounted; then
          rw_matches ||
            die "$RW is mounted from an unexpected device or filesystem"
        elif overlay_mounted; then
          die "$STORE overlay exists, but its RW backing mount is absent"
        fi

        mkdir -p "$RW"

        if ! rw_is_mounted; then
          local opts=()
          [[ "$RW_FSTYPE" == auto ]] || opts+=(-t "$RW_FSTYPE")
          [[ -z "$RW_OPTIONS" ]] || opts+=(-o "$RW_OPTIONS")

          mount "''${opts[@]}" "$RW_DEVICE" "$RW" ||
            die "failed to mount $RW_DEVICE at $RW"

          rw_matches ||
            die "RW mount does not match the expected device and filesystem"
        fi

        mkdir -p "$RW/upper" "$RW/work"

        if ! overlay_mounted; then
          mount -t overlay overlay \
            -o "lowerdir=$RO,upperdir=$RW/upper,workdir=$RW/work" \
            "$STORE" ||
            die "failed to mount overlay at $STORE"
        fi

        overlay_matches ||
          die "overlay mount does not match the expected configuration"
      }

      down() {
        local store=0 rw=0

        if overlay_mounted; then
          overlay_matches ||
            die "$STORE has an overlay, but not the expected one"
          store=1
        fi

        if rw_is_mounted; then
          rw_matches ||
            die "$RW is mounted from an unexpected device or filesystem"
          rw=1
        fi

        if [[ "$store" == 1 && "$rw" == 0 ]]; then
          die "$STORE overlay exists, but the expected RW filesystem is absent"
        fi

        if [[ "$store" == 1 ]]; then
          release "$STORE" overlay_matches
        fi

        if [[ "$rw" == 1 ]]; then
          release "$RW" rw_matches
        fi
      }

      case "''${1:-}" in
        up)   up ;;
        down) down ;;
        *)    echo "usage: nix-store-rw up|down" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  # groups and options are sorted alphabetically
  options =
    with self.lib.options;
    mkOptions {
      enable = mkBoolOption "enable functionnal nix-store (writable and usable)" true;

      db.path = mkPathOption "where the nix database is stored (symlinked from /nix/var/nix/db)" "/var/lib/nix-db";

      # the device holding the rw layer
      device = {
        fsType = mkTypedOption (types.autoOr types.fsType) "filesystem of the rw device" "btrfs";
        label = mkStrOption "partition label of the rw device" "${meta.name}-store-rw";
        mountPoint = mkPathOption "where the rw device is mounted" "/nix/.rw-store";
        options = mkTypedOption (with lib.types; listOf str) "extra mount options for the rw device" [ ];
      };

      # everything about failures
      errors = {
        busy = {
          fallback =
            mkEnumOption
              ''
                what to do when the store is still busy after the timeout.
                lazy : detach now, open files keep seeing the old mount.
                fail : leave the mount in place and mark the unit failed.
              ''
              [
                "lazy"
                "fail"
              ]
              "lazy";
          timeout = mkIntOption "seconds to retry unmounting a busy store before the fallback" 30;
        };
        retryDelay = mkIntOption "seconds before retrying a failed mount" 5;
      };
    };

  config = mkIfEnable (
    lib.mkMerge [
      # always : read-only store, no rw layer
      {
        fileSystems.${storePath} = {
          device = roMount;
          fsType = "none";
          options = [
            "bind"
            "ro"
          ];
          neededForBoot = true;
        };
      }

      # only with the rw layer
      (lib.mkIf cfg.enable {
        # make sure the kernel supports the rw filesystem
        boot.supportedFilesystems = lib.mkIf (cfg.device.fsType != "auto") {
          ${cfg.device.fsType} = true;
        };

        # the db should be linked from persistent storage with a symlink
        systemd.tmpfiles.rules = [
          "d /nix/var/nix 0755 root root -"
          "d ${cfg.db.path} 0755 root root -"
          "L+ ${dbLink} - - - - ${cfg.db.path}"
        ];

        systemd.services = {
          # mounts the rw device
          # and overlay over /nix/store
          nix-store-rw = {
            description = "read-write nix store layer";
            wantedBy = [ devUnit ];
            bindsTo = [ devUnit ];
            after = [ devUnit ];
            # before = [ "nix-daemon.socket" ] # not necessary because set in the service bellow
            wants = [ "nix-daemon.socket" ];
            unitConfig = {
              RequiresMountsFor = [
                roMount
                storePath
                cfg.db.path
              ];
              # never give up retrying
              StartLimitIntervalSec = 0;
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Restart = "on-failure";
              RestartSec = cfg.errors.retryDelay;
              # must outlast the busy retry loop (store, then rw)
              TimeoutStopSec = cfg.errors.busy.timeout * 2 + 15;
            };
            script = "${lib.getExe nix-store-rw} up";
            # runs on stop and on failed start
            postStop = "${lib.getExe nix-store-rw} down";
          };

          # daemon lives and dies with the rw layer
          nix-daemon = {
            bindsTo = [ "nix-store-rw.service" ];
            after = [ "nix-store-rw.service" ];
            wantedBy = lib.mkForce [ ];
          };
        };

        systemd.sockets.nix-daemon = {
          bindsTo = [ "nix-store-rw.service" ];
          after = [ "nix-store-rw.service" ];
          wantedBy = lib.mkForce [ ];
        };

        nix.enable = lib.mkForce true;
      })
    ]
  );
}
