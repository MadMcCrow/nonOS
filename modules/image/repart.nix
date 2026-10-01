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
    mkDeviceUnit = disk: with lib; replaceStrings [ "-" "/" ] [ "\\x2d" "-" ] "${removePrefix "/" disk}.device";

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
      device = mkDevice {
        description = "main installation device, will be generated at boot";
        default = "/dev/disk/by-label/nonos-main";
      };
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
    boot.initrd = {
      # add repart to initrd
      systemd = {
        # don't wait too much
        settings.Manager = {
          DefaultTimeoutStopSec = "10s";
        };
        # make sure that some coreutils are available
        storePaths = [
        ];
        repart = {
          enable = true;
          inherit (cfg) device;
        };
        # detect disk
        services."detect-repart-disk" = let
          neededBy = map (x: mkDeviceUnit cfg.${x}.device) ["home" "var"];
          script = pkgs.writeShellApplication {
            name ="link-store-disk";
            runtimeInputs = [ pkgs.util-linux ];
            text =  ''
              set -x
              # resolve to actual disk link
              dev="$(readlink -f "${nix-store}")"
              disk="$(lsblk -ndo PKNAME "$dev")"
              if [ -z "$disk" ]; then
                echo "Could not determine parent disk of ${nix-store} " >&2
                exit 1
              fi
              disk="/dev/$disk"
              echo "linking ${cfg.device} to $disk"
              rm -f "${cfg.device}" && true
              ln -s "$disk" "${cfg.device}"
            '';
          };
        in
        {
            description = "resolve disk backing nix-ro-store partition";
            # needed by repart
            after = [ (mkDeviceUnit nix-store) ];
            requires = [ (mkDeviceUnit nix-store) ];
            before = [ "systemd-repart.service" ];
            wantedBy = [ "systemd-repart.service" ] ++ neededBy;
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StandardOutput = "journal";
              StandardError = "journal";
              ExecStart = "${lib.getExe linkStoreDiskScript}";
            };
          };
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
