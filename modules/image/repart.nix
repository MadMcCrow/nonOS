# image.nix
# nix store is in an overlay fs
# This means we have to handle the read-only filesystem
# as well as the writable one.
{
  modConfig,
  mkOptions,
  inputs,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  mkDevice =
    args:
    lib.mkOption {
      type = lib.types.nonEmptyStr;
      example = "/dev/disk/by-UUID/xxxx-xxxx-xxxx";
    }
    // args;

  nix-store = "/dev/disk/by-partlabel/nix-ro-store";
  # assumes disk path is r"[a-zA-Z0-9/-]+"
  # if disk contains other systemd-escape-special chars we should escape them
  mkDeviceUnit =
    disk:
    with lib;
    unsafeDiscardStringContext (
      replaceStrings [ "-" "/" ] [ "\\x2d" "-" ] "${removePrefix "/" disk}.device"
    );
in
with (modConfig config);
{
  options =
    let
      fsOption =
        {
          name,
          enabled,
          priority,
        }:
        {
          enable = lib.mkEnableOption "${name} fileSystems" // {
            default = enabled;
          };
          device = mkDevice {
            description = "block device to use for ${name} filesystem";
            default = "/dev/disk/by-partlabel/${name}";
          };
          fsType = lib.mkOption {
            description = "file system type";
            type = lib.types.nonEmptyStr;
            default = "ext4";
          };
          priority = lib.mkOption {
            description = "repart priority";
            type = lib.types.int;
            default = priority;
          };
        };
    in
    mkOptions {
      var = fsOption {
        name = "var";
        enabled = true;
        priority = 1000;
      };
      home = fsOption {
        name = "home";
        enabled = true;
        priority = 2000;
      };
    };

  config = mkIfEnable {
    # add repart to initrd
    boot.initrd.systemd = {
      # don't wait too much
      settings.Manager = {
          DefaultTimeoutStartSec = "10s";
          DefaultTimeoutStopSec = "10s";
      };
      # make sure that the script can run
      storePaths = with pkgs; [
        "${util-linux}/bin/lsblk"
        "${coreutils}/bin/readlink" # uutils-coreutils is slightly larger
      ];

      # no device : we override behaviour to "detect" the partitions ourselves
      repart.enable = true;

      # detect disk and run the actual repart
      services.systemd-repart =
        let
          repartRun = pkgs.writeShellScript "repart-run" ''
            set -euo pipefail
            dev="$(readlink -f "${nix-store}")"
            disk="/dev/$(lsblk -ndo PKNAME "$dev")"
            echo "repart on $disk"
            exec ${config.boot.initrd.systemd.package}/bin/systemd-repart \
              --definitions=/etc/repart.d --dry-run=no "$disk"
          '';
        in
        {
          # needed by repart
          after = [ (mkDeviceUnit nix-store) ];
          requires = [ (mkDeviceUnit nix-store) ];
          serviceConfig.ExecStart = lib.mkForce [
            ""
            "${repartRun}"
          ];
          before = map (x: mkDeviceUnit cfg.${x}.device) [
            "home"
            "var"
          ];
          path = with pkgs; [
            util-linux
            coreutils
          ];
        };
    };

    # add the filesystems
    fileSystems = lib.mkMerge (
      map
        (
          name:
          lib.mkIf cfg.${name}.enable {
            "/${name}" = {
              inherit (cfg.${name}) fsType device;
              options = [ "x-systemd.device-timeout=10s" ];
            };
          }
        )
        [
          "home"
          "var"
        ]
    );

    systemd.enableStrictShellChecks = true;

    # extra partitions :
    systemd.repart.partitions = lib.mkMerge (
      map
        (
          name:
          lib.mkIf cfg.${name}.enable {
            "${name}" = {
              Format = cfg.${name}.fsType;
              Label = "${name}";
              Type = "${name}";
              Weight = cfg.${name}.priority;
            };
          }
        )
        [
          "home"
          "var"
        ]
    );
  };
}
