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
with (modConfig config);
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

  # repart devices :
  devices = map (x: (cfg.${x} // { name = x; })) [
    "home"
    "var"
  ];

  repartRun = pkgs.writeShellScriptBin "repart-run" ''
    set -euo pipefail
    repart="${config.boot.initrd.systemd.package}/bin/systemd-repart"
    store="$(readlink -f "${nix-store}")"
    sysdisk="/dev/$(lsblk -ndo PKNAME "$store")"

    echo "repart on $sysdisk"
    "$repart" --definitions=/etc/repart.d --dry-run=no "$sysdisk"

    data="${if cfg.dataDisk != null then cfg.dataDisk else ""}"
    if [ -z "$data" ]; then
      data="$(lsblk -bdnpo NAME,TYPE,RM,SIZE \
        | awk -v s="$sysdisk" '$2=="disk" && $3==0 && $1!=s && $1!~/zram/ {print $4, $1}' \
        | sort -rn | head -1 | cut -d' ' -f2)"
    fi
    [ -n "$data" ] || { echo "no data disk"; exit 0; }
    data="$(readlink -f "$data")"

    if lsblk -nro PARTLABEL "$data" | grep -qx nix-rw \
       || [ -z "$(wipefs -n "$data")" ]; then
      echo "repart on $data"
      "$repart" --definitions=/etc/repart-data.d --empty=allow --dry-run=no "$data"
    else
      echo "foreign data on $data, skipping"
    fi
  '';
in
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
      # make sure that the script can run
      storePaths = with pkgs; [
        "${util-linux}/bin/lsblk"
        "${util-linux}/bin/wipefs"
        "${coreutils}/bin/readlink" # uutils-coreutils is slightly larger
        "${gawk}/bin/gawk"
      ];

      # no device : we override behaviour to "detect" the partitions ourselves
      repart.enable = true;

      # detect disk and run the actual repart
      services.systemd-repart = {
          # needed by repart
          after = [ (mkDeviceUnit nix-store) ];
          requires = [ (mkDeviceUnit nix-store) ];
          serviceConfig.ExecStart = lib.mkForce [
            ""
            "${lib.getExe repartRun}"
          ];
          before = map (x: mkDeviceUnit x.device) devices;
          path =
            with pkgs;
            [
              repartRun
              util-linux
              coreutils
              gawk
            ]
            ++ (
              let
                rules = [
                  {
                    pattern = "ext[234]";
                    package = pkgs.e2fsprogs;
                  }
                  {
                    pattern = "btrfs";
                    package = pkgs.btrfs-progs;
                  }
                  {
                    pattern = "xfs";
                    package = pkgs.xfsprogs;
                  }
                ];
                packageFor =
                  fs: map (rule: rule.package) (pkgs.lib.filter (rule: pkgs.lib.match rule.pattern fs != null) rules);
              in
              pkgs.lib.unique (pkgs.lib.concatMap packageFor (map (x: x.fsType) devices))
            );
        };
    };

    # add the filesystems
    fileSystems = lib.mkMerge (
      map (
        dev:
        lib.mkIf dev.enable {
          "/${dev.name}" = {
            inherit (dev) fsType device;
            # it's either there, or it isn't !
            options = [
              "defaults"
              "x-systemd.device-timeout=10s"
            ];
          };
        }
      ) devices
    );

    systemd.enableStrictShellChecks = true;

    # extra partitions :
    systemd.repart.partitions = lib.mkMerge (
      map (
        dev:
        lib.mkIf dev.enable {
          "${dev.name}" = {
            Format = dev.fsType;
            Label = "${dev.name}";
            Type = "${dev.name}";
            Weight = dev.priority;
          };
        }
      ) devices
    );
  };
}
