# main.nix
# main disk image
# How to build the image and how the base repart will act.
# This is the core of the image module
{
  modConfig,
  mkOptions,
  inputs,
  self,
  ...
}:
{
  pkgs,
  lib,
  config,
  ...
}:
with (modConfig config);
let
# the currently activated slot store
storeDevice = "/dev/disk/by-partlabel/${cfg.slot.currentLabel}";

# assumes disk path is r"[a-zA-Z0-9/_.-]+"
mkDeviceUnit =
  disk:
  lib.unsafeDiscardStringContext (
    lib.replaceStrings [ "-" "/" ] [ "\\x2d" "-" ] "${lib.removePrefix "/" disk}.device"
  );

  # correct tool for each filesystem
  fsTools = with lib; with builtins; with pkgs;
    fs: map (x: elemAt x 1) (filter (x: elemAt x 0) [
      [(hasPrefix "ext" fs) e2fsprogs   ]
      [(fs == "btrfs")      btrfs-progs ]
      [(fs == "xfs")        xfsprogs    ]
      [(fs == "f2fs")       f2fs-tools  ]
    ]);

    # script to wrap the default systemd-repart to do it on the main disk
    systemd-repart-exe = pkgs.writeShellApplication {
      name = "repart-system";
      runtimeInputs = [
        config.boot.initrd.systemd.package
        pkgs.util-linux
        pkgs.coreutils
      ]
      ++ (fsTools cfg.var.fsType);
      text = ''
        sysdisk="/dev/$(lsblk -ndo PKNAME "$(readlink -f "${storeDevice}")")"
        echo "repart on $sysdisk"
        systemd-repart --definitions=/etc/repart.d --dry-run=no "$sysdisk"
      '';
    };
in
{

  # we need repart
  imports = [ "${inputs.nixpkgs}/nixos/modules/image/repart.nix" ];


  options = with (self.lib.options); mkOptions {
      # boot partition
      esp = {
        size = mkSizeOption "mkSizeOption of the ESP" "512M";
        boot = mkStrOption "ESP label" "boot";
      };
      # squashfs slot (ro-nix-store)
      slot = {
        size = mkSizeOption "mkSizeOption of each store slot" "4G";
        emptyLabel = mkStrOption "label of a never-written slot" "_empty";
        currentLabel =  mkStrOption "store slot label for current version" "nix-store_${config.system.image.version}";
      };
      # var partition ( state )
      var = {
        enable = mkBoolOption "enable the var partition on main disk" true;
        label = mkStrOption "var partition label" "var";
        fsType = mkFsOption "var partition type"  "ext4";
        weight = mkIntOption "priority of var partition" 1500;
      };

  };

  config = mkIfEnable {

    boot.initrd.systemd = {
      repart.enable = true;
      # keep tools reachable inside the initrd
      storePaths = [ systemd-repart-exe ];
      # override the default systemd-repart
      services.systemd-repart = {
        after = [ (mkDeviceUnit storeDevice) ];
        requires = [ (mkDeviceUnit storeDevice) ];
        serviceConfig.ExecStart = lib.mkForce [
          ""
          "${lib.getExe systemd-repart-exe}"
        ];
      };
    };


    fileSystems = {
      "/boot" = {
        device = "/dev/disk/by-partlabel/${cfg.esp.label}";
        fsType = "vfat";
      };
    # only the ro slot is static
    "/nix/.ro-store" = {
        device = "/dev/disk/by-partlabel/${cfg.slot.currentLabel}";
        fsType = "squashfs";
        options = [ "ro" ];
        neededForBoot = true;
    };

    image.repart = {
      enable = true;
      name = "image";
      # one file per partition : used by the update bundle
      split = true;
      partitions = {
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
            Type = "esp";
            Format = "vfat";
            Label = cfg.esp.label;
            SizeMinBytes = cfg.esp.size;
            SizeMaxBytes = cfg.esp.size;
          };
        };
        nix-store = {
          storePaths = [ config.system.build.toplevel ];
          nixStorePrefix = "/";

          repartConfig = {
            Type = "linux-generic";
            Format = "squashfs";
            Label = cfg.slot.storeRo;
            # fixed size : the slot must also fit the next version;
            Minimize = "off";
            SizeMinBytes = cfg.slot.size;
            SizeMaxBytes = cfg.slot.size;
            ReadOnly = "yes";
          };
        };
      };
    };

    # check our scripts
    systemd.enableStrictShellChecks = true;

    # repart default partitions
    systemd.repart.partitions = {
      "10-nix-store-a" = {
        Type = "linux-generic";
        SizeMinBytes = cfg.slot.size;
        SizeMaxBytes = cfg.slot.size;
      };
      "20-nix-store-b" = {
        Type = "linux-generic";
        Label = cfg.slot.emptyLabel;
        SizeMinBytes = cfg.slot.size;
        SizeMaxBytes = cfg.slot.size;
        ReadOnly = "yes";
      };
      "30-var" = lib.mkIf cfg.var.enable {
        Type = "var";
        Label = cfg.var.label;
        Format = cfg.var.fsType;
        Weight = cfg.var.weight;
      };
    };
  };
}
