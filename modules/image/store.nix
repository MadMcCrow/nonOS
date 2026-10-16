# store.nix
# /nix/store = overlay(ro squashfs slot, rw fs on the data disk)
# Without the rw device, /nix/store is the ro slot and nix-daemon is down.
# When the rw device appears, the overlay is mounted and nix-daemon starts.
# When it disappears, everything is torn down in reverse order.
{
  mkModule,
  mkOptions,
  self,
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
  nix-store-rw =
    let
      sh = lib.escapeShellArg;
    in
    pkgs.writeShellApplication {
      name = "nix-store-rw";
      runtimeInputs = with pkgs; [
        util-linux
        coreutils
        psmisc
      ];
      runtimeEnv =
        let
          sh = lib.escapeShellArg;
        in
        {
          RO = sh roMount;
          STORE = sh storePath;
          RW = sh cfg.slot.mount;
          RW_DEVICE = sh device;
          RW_FSTYPE = sh cfg.device.fsType;
          RW_OPTIONS = sh (lib.concatStringsSep "," cfg.device.options);
          BUSY_TIMEOUT = sh (toString cfg.busy.timeout);
          BUSY_FALLBACK = sh cfg.busy.fallback;
        };
      text = ''
        lazy=0

        die() {
          echo "nix-store-rw: $*" >&2
          exit 1
        }

        store_is_mounted() { mountpoint -q "$STORE"; }
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
          local fs opts

          fs=$(findmnt -n -l -M "$STORE" -o FSTYPE) || return 1
          [[ "$fs" == overlay ]] || return 1

          opts=$(findmnt -n -l -M "$STORE" -o FS-OPTIONS) || return 1
          has_option "$opts" "lowerdir=$RO" &&
            has_option "$opts" "upperdir=$RW/upper" &&
            has_option "$opts" "workdir=$RW/work"
        }

        rw_matches() {
          local fs mounted_dev expected_dev

          [[ -b "$RW_DEVICE" ]] || return 1

          fs=$(findmnt -n -l -M "$RW" -o FSTYPE) || return 1
          [[ "$fs" == "$RW_FSTYPE" ]] || return 1

          mounted_dev=$(findmnt -n -l -M "$RW" -o MAJ:MIN) || return 1
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

          if store_is_mounted; then
            overlay_matches ||
              die "$STORE is mounted, but is not the expected overlay"
          fi

          if rw_is_mounted; then
            rw_matches ||
              die "$RW is mounted from an unexpected device or filesystem"
          elif store_is_mounted; then
            die "$STORE overlay exists, but its RW backing mount is absent"
          fi

          mkdir -p "$RW"

          if ! rw_is_mounted; then
            local opts=()
            [[ -z "$RW_OPTIONS" ]] || opts=(-o "$RW_OPTIONS")

            mount -t "$RW_FSTYPE" "''${opts[@]}" "$RW_DEVICE" "$RW" ||
              die "failed to mount $RW_DEVICE at $RW"

            rw_matches ||
              die "RW mount does not match the expected device and filesystem"
          fi

          mkdir -p "$RW/upper" "$RW/work"

          if ! store_is_mounted; then
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

          if store_is_mounted; then
            overlay_matches ||
              die "$STORE is mounted, but is not the expected overlay"
            store=1
          fi

          if rw_is_mounted; then
            rw_matches ||
              die "$RW is mounted from an unexpected device or filesystem"
            rw=1
          fi

          if [[ "$store" == 1 && "$rw" == 0 ]]; then
            die "$STORE is mounted, but the expected RW filesystem is absent"
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
  options =
    with self.lib.options;
    mkOptions {
      # TODO : sort and regroup options
      writable = {
        label = mkStrOption "label of partition holding the rw layer" "store-rw";
        mountPoint = mkPathOption "where the rw device is mounted" "/nix/.rw-store";

        # TODO : Allow auto
        fsType = mkFsOption "filesystem of the rw device" "btrfs";
        options = mkTypedOption (with lib.types; listOf str) "extra mount options for the rw device" [ ];
        # TODO : regroup with busy ( error management )
        retry.delay = mkIntOption "seconds before retrying a failed mount" 5;
        busy = {
          timeout = mkIntOption "seconds to retry unmounting a busy store before the fallback" 30;
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
        };
      };
      db.path = mkPathOption "where the nix database is stored (symlinked from /nix/var/nix/db)" "/var/lib/nix-db";
      daemon.enable = mkBoolOption "run nix-daemon only while the rw layer is mounted" true;
    };

  config = mkIfEnable {
    # base state : read-only store, no rw layer
    fileSystems.${storePath} = {
      device = roMount;
      fsType = "none";
      options = [
        "bind"
        "ro"
      ];
      neededForBoot = true;
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
        wants = lib.optional cfg.daemon.enable "nix-daemon.socket";
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
          RestartSec = cfg.device.retry.delay;
          # must outlast the busy retry loop
          TimeoutStopSec = cfg.device.busy.timeout * 2 + 15;
        };
        script = "${lib.getExe nix-store-rw} up";
        # runs on stop and on failed start
        postStop = "${lib.getExe nix-store-rw} down";
      };

      # daemon lives and dies with the rw layer
      nix-daemon = lib.mkIf cfg.daemon.enable {
        bindsTo = [ "nix-store-rw.service" ];
        after = [ "nix-store-rw.service" ];
        wantedBy = lib.mkForce [ ];
      };
    };

    systemd.sockets.nix-daemon = lib.mkIf cfg.daemon.enable {
      bindsTo = [ "nix-store-rw.service" ];
      after = [ "nix-store-rw.service" ];
      wantedBy = lib.mkForce [ ];
    };

    nix.enable = lib.mkIf cfg.daemon.enable (lib.mkForce true);
  };
}
