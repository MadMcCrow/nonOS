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
        default = "/dev/disk/nonos-main";
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
    # add repart to initrd
    boot.initrd.systemd = {
      # make sure that some coreutils are available
      storePaths = [
        "${pkgs.coreutils}/bin/basename"
        "${pkgs.coreutils}/bin/readlink"
        "${pkgs.coreutils}/bin/ln"
        "${pkgs.gnugrep}/bin/grep"
      ];
      repart = {
        enable = true;
        inherit (cfg) device;
      };
      services."detect-repart-disk" =
      let
        nix-store = "/dev/disk/by-partlabel/nix-ro-store";
        # assumes disk path is r"[a-zA-Z0-9/-]+"
        # if disk contains other systemd-escape-special chars we should escape them
        mkDeviceUnit =
          disk: with lib; replaceStrings [ "-" "/" ] [ "\\x2d" "-" ] "${removePrefix "/" disk}.device";
      in
      {
        description = "resolve disk backing nix-ro-store partition";
        before = [ "systemd-repart.service" ];
        after = [
          "systemd-udev-settle.service"
          "sysinit.target"
          (mkDeviceUnit nix-store)
        ];
         unitConfig.DefaultDependencies = false;
        requires = [ (mkDeviceUnit nix-store) ];
        # needed by systemd-repart and by mounting the repart directories
        wantedBy = [
          "systemd-repart.service"
          (mkDeviceUnit cfg.device)
        ]
        ++ (map (x: mkDeviceUnit "/dev/by-partlabel/${x}") [
          "home"
          "var"
        ]);
        serviceConfig.Type = "oneshot";
        script = ''
          part=$(readlink -f ${nix-store})
          partname=$(basename "$part")
          diskname=$(basename "$(readlink -f /sys/class/block/$partname/..)")
          ln -sf "/dev/$diskname" "${cfg.device}"
        '';
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
