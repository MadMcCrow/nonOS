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
  ...
}:
let
  mkdevice =
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
      filesystemOption =
        {
          name,
          enabled,
          priority,
        }:
        {
          enable = lib.mkEnableOption "${name} fileSystems" // {
            default = enabled;
          };
          device = mkdevice {
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
      device = mkdevice {
        description = "main installation device";
      };
      var = filesystemOption {
        name = "var";
        enabled = true;
        priority = 1000;
      };
      home = filesystemOption {
        name = "home";
        enabled = true;
        priority = 2000;
      };
    };

  imports = [
    "${inputs.nixpkgs}/nixos/modules/image/repart.nix"
  ];

  config = mkIfEnable {
    # add repart to initrd
    boot.initrd.systemd.repart = {
      enable = true;
      inherit (cfg) device;
    };

    fileSystems = lib.mkMerge (
      [
        {
          # root is on tmpfs
          "/" = {
            fsType = "tmpfs";
            #options = [ "size=100m" ];
          };
          # boot filesystem
          "/boot" = {
            device = "/dev/disk/by-partlabel/boot";
            fsType = "vfat";
          };
          # the image read-only squashfs store
          "/nix/.ro-store" = {
            device = "/dev/disk/by-partlabel/nix-ro-store";
            fsType = "squashfs";
            options = [ "ro" ];
            neededForBoot = true;
          };
          # add our optional filesystems
        }
      ]
      ++ (map (
        name:
        lib.mkIf cfg.${name}.enable {
          "/${name}" = {
            inherit (cfg.${name}) fsType device;
          };
        }
      ) "home" "var")
    );

    image.repart = {
      name = "image";
      partitions = {
        # read-only store image
        nix-ro-store = {
          storePaths = [ config.system.build.toplevel ];
          nixStorePrefix = "/";
          repartConfig = {
            Format = "squashfs";
            Label = "nix-ro-store";
            Minimize = "guess";
            ReadOnly = "yes";
            Type = "linux-generic";
          };
        };
        # EFI partition image
        esp = {
          contents =
            let
              inherit (pkgs.stdenv.hostPlatform) efiArch;
            in
            {
              "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
                "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

              "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
            };
          repartConfig = {
            Format = "vfat";
            Label = "boot";
            SizeMinBytes = "200M";
            Type = "esp";
          };
        };
      }; # end of partitions
    };

    # extra partitions :
    systemd.repart.partitions = lib.mkMerge (
      map
        (
          name:
          lib.mkIf cfg.${name}.enable {
            "${name}" = {
              Format = cfg.${name}.fstype;
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
