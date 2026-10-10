# sysdisk.nix
# first boot, system disk (Optane) : slot B + var
{
  modConfig,
  mkOptions,
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
  inherit (mod) layout;
  storeDevice = "/dev/disk/by-partlabel/${layout.labels.storeRo}";

  # assumes disk path is r"[a-zA-Z0-9/_.-]+"
  mkDeviceUnit =
    disk:
    lib.unsafeDiscardStringContext (
      lib.replaceStrings [ "-" "/" ] [ "\\x2d" "-" ] "${lib.removePrefix "/" disk}.device"
    );

  fsTools =
    fs:
    (lib.optional (lib.hasPrefix "ext" fs) pkgs.e2fsprogs)
    ++ (lib.optional (fs == "btrfs") pkgs.btrfs-progs)
    ++ (lib.optional (fs == "xfs") pkgs.xfsprogs);

  runner = pkgs.writeShellApplication {
    name = "repart-system";
    runtimeInputs = [
      config.boot.initrd.systemd.package
      pkgs.util-linux
      pkgs.coreutils
    ]
    ++ (fsTools cfg.var.fsType);
    text = ''
      udevadm settle --timeout=10
      sysdisk="/dev/$(lsblk -ndo PKNAME "$(readlink -f "${storeDevice}")")"
      echo "repart on $sysdisk"
      systemd-repart --definitions=/etc/repart.d --dry-run=no "$sysdisk"
      udevadm settle --timeout=10
    '';
  };
in
{
  options = mkOptions {
    var = {
      enable = lib.mkEnableOption "var partition" // {
        default = true;
      };
      fsType = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "ext4";
      };
      weight = lib.mkOption {
        description = "repart weight";
        type = lib.types.int;
        default = 1000;
      };
    };
  };

  config = mkIfEnable {
    boot.initrd.systemd = {
      repart.enable = true;
      # keep tools reachable inside the initrd
      storePaths = [ runner ];
      services.systemd-repart = {
        after = [ (mkDeviceUnit storeDevice) ];
        requires = [ (mkDeviceUnit storeDevice) ];
        serviceConfig.ExecStart = lib.mkForce [
          ""
          "${lib.getExe runner}"
        ];
      };
    };

    # A and B both need an entry : repart matches existing partitions by type.
    systemd.repart.partitions = {
      "10-nix-store-a" = {
        Type = "linux-generic";
        SizeMinBytes = layout.slotSize;
        SizeMaxBytes = layout.slotSize;
      };
      "20-nix-store-b" = {
        Type = "linux-generic";
        Label = layout.labels.storeEmpty;
        SizeMinBytes = layout.slotSize;
        SizeMaxBytes = layout.slotSize;
        ReadOnly = "yes";
      };
      "30-var" = lib.mkIf cfg.var.enable {
        Type = "var";
        Label = layout.labels.var;
        Format = cfg.var.fsType;
        Weight = cfg.var.weight;
      };
    };

    fileSystems."/var" = lib.mkIf cfg.var.enable {
      device = "/dev/disk/by-partlabel/${layout.labels.var}";
      inherit (cfg.var) fsType;
      options = [
        "defaults"
        "x-systemd.device-timeout=10s"
      ];
    };

    systemd.enableStrictShellChecks = true;
  };
}
