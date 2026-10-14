# store.nix
# /nix/store = overlay(ro squashfs slot, rw fs on the data disk)
# Without the rw device, /nix/store is the ro slot and nix-daemon is down.
# When the rw device appears, the overlay is mounted and nix-daemon starts.
# When it disappears, everything is torn down in reverse order.
{
  modConfig,
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
with (modConfig config);
let
  # constants. The ro slot is mounted here by image.nix : keep in sync.
  roMount = "/nix/.ro-store";
  storePath = "/nix/store";
  dbLink = "/nix/var/nix/db";

  # the .device unit systemd creates when udev reports the rw device
  devUnit = "${utils.escapeSystemdPath cfg.rw.device}.device";

  rw = lib.escapeShellArg cfg.rw.mount;
  mountOpts = lib.optionalString (cfg.rw.options != [ ]) "-o ${lib.escapeShellArg (lib.concatStringsSep "," cfg.rw.options)}";

  # what to do when a mount is still busy after the timeout
  busyFallback =
    {
      lazy = ''
        echo "$target still busy after ${toString cfg.busy.timeout}s : lazy detach" >&2
        umount -l "$target" || true
        lazy=1
      '';
      fail = ''
        echo "$target still busy after ${toString cfg.busy.timeout}s : giving up" >&2
        exit 1
      '';
    }
    .${cfg.busy.fallback};
in
{
  options =
    with self.lib.options;
    mkOptions {
      rw = {
        device = mkStrOption "device holding the rw layer (must be a udev symlink or node)" "/dev/disk/by-partlabel/store-rw";
        mount = mkPathOption "where the rw device is mounted" "/nix/.rw-store";
        fsType = mkFsOption "filesystem of the rw device" "btrfs";
        options = lib.mkOption {
          description = "extra mount options for the rw device";
          type = with lib.types; listOf str;
          default = [ ];
        };
      };

      db.path = mkPathOption "where the nix database is stored (symlinked from /nix/var/nix/db)" "/var/lib/nix-db";

      retry.delay = mkIntOption "seconds before retrying a failed mount" 5;

      busy = {
        timeout = mkIntOption "seconds to retry unmounting a busy store before the fallback" 30;
        fallback = lib.mkOption {
          description = ''
            what to do when the store is still busy after the timeout.
            lazy : detach now, open files keep seeing the old mount.
            fail : leave the mount in place and mark the unit failed.
          '';
          type = lib.types.enum [
            "lazy"
            "fail"
          ];
          default = "lazy";
        };
      };

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
        path = [
          pkgs.util-linux
          pkgs.coreutils
          pkgs.psmisc
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = cfg.retry.delay;
          # must outlast the busy retry loop
          TimeoutStopSec = cfg.busy.timeout * 2 + 15;
        };
        script = ''
          set -euo pipefail
          mkdir -p ${rw}
          if ! mountpoint -q ${rw}; then
            mount -t ${cfg.rw.fsType} ${mountOpts} ${lib.escapeShellArg cfg.rw.device} ${rw}
          fi
          mkdir -p ${rw}/upper ${rw}/work
          mount -t overlay overlay \
            -o lowerdir=${lib.escapeShellArg roMount},upperdir=${rw}/upper,workdir=${rw}/work \
            ${storePath}
        '';
        # runs on stop and on failed start
        postStop = ''
          lazy=0

          overlay_mounted() {
            [ "$(findmnt -nro FSTYPE --target ${storePath})" = overlay ]
          }
          rw_mounted() {
            mountpoint -q ${rw}
          }

          # release TARGET CHECK : unmount while CHECK is true, retry while busy
          release() {
            target="$1"
            check="$2"
            if [ "$lazy" = 1 ]; then
              umount -l "$target" || true
              return 0
            fi
            deadline=$((SECONDS + ${toString cfg.busy.timeout}))
            while "$check"; do
              if umount "$target" 2>/dev/null; then
                continue
              fi
              if [ "$SECONDS" -ge "$deadline" ]; then
                fuser -vm "$target" >&2 || true
                ${busyFallback}
                break
              fi
              sleep 1
            done
          }

          release ${storePath} overlay_mounted
          release ${rw} rw_mounted
        '';
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

    # the daemon unit must exist. minimize.nix only sets a default.
    nix.enable = lib.mkIf cfg.daemon.enable (lib.mkForce true);
  };
}
