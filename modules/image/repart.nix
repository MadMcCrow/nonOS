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
        "${coreutils}/bin/readlink" # uutils-coreutils is slightly larger
      ];

      # no device : we override behaviour to "detect" the partitions ourselves
      repart.enable = true;

      # detect disk and run the actual repart
      services.systemd-repart =
        let
          repartRun = pkgs.writeShellScriptBin "repart-run" ''
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
            "${lib.getExe repartRun}"
          ];
          before = map (x: mkDeviceUnit x.device) devices;
          path =
            with pkgs;
            [
              repartRun
              util-linux
              coreutils
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
