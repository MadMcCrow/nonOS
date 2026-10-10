# datadisk.nix
# first boot, data disk (SATA) : nix-rw + home
# Autodetect. Never touches a foreign disk.
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

  fsTools =
    fs:
    (lib.optional (lib.hasPrefix "ext" fs) pkgs.e2fsprogs)
    ++ (lib.optional (fs == "btrfs") pkgs.btrfs-progs)
    ++ (lib.optional (fs == "xfs") pkgs.xfsprogs)
    ++ (lib.optional (fs == "f2fs") pkgs.f2fs-tools);

  # empty dirs copied into nix-rw at creation
  skeleton = pkgs.runCommand "nix-rw-skeleton" { } ''
    mkdir -p $out/{upper,work,var,tmp}
    chmod 1777 $out/tmp
  '';

  runner = pkgs.writeShellApplication {
    name = "repart-data";
    runtimeInputs = [
      config.boot.initrd.systemd.package
      pkgs.util-linux
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
    ]
    ++ (fsTools layout.rwFsType)
    ++ (fsTools cfg.home.fsType);
    text = ''
      udevadm settle --timeout=10
      sysdisk="/dev/$(lsblk -ndo PKNAME "$(readlink -f "${storeDevice}")")"

      data=${lib.escapeShellArg (if cfg.disk == null then "" else cfg.disk)}
      if [ -z "$data" ]; then
        # largest non-removable disk that is not the system disk
        data="$(lsblk -bdnpo NAME,TYPE,RM,SIZE \
          | awk -v s="$sysdisk" '$2=="disk" && $3==0 && $1!=s && $1!~/zram/ {print $4, $1}' \
          | sort -rn | sed -n 1p | cut -d' ' -f2)"
      fi
      [ -n "$data" ] || { echo "no data disk"; exit 0; }
      data="$(readlink -f "$data")"

      labels="$(lsblk -nro PARTLABEL "$data")"
      if grep -qx ${layout.labels.storeRw} <<<"$labels" || [ -z "$(wipefs -n "$data")" ]; then
        echo "repart on $data"
        systemd-repart --definitions=/etc/repart-data.d --empty=allow --dry-run=no "$data"
        udevadm settle --timeout=10
      else
        echo "foreign data on $data, skipping"
      fi
    '';
  };
in
{
  options = mkOptions {
    enable = lib.mkEnableOption "auto-partitioning of a data disk" // {
      default = true;
    };
    disk = lib.mkOption {
      description = "data disk (use /dev/disk/by-id/...). null means autodetect.";
      type = with lib.types; nullOr path;
      default = null;
    };
    nixRw = {
      minSize = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "64G";
      };
      maxSize = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "512G";
      };
    };
    home = {
      fsType = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "ext4";
      };
      weight = lib.mkOption {
        description = "repart weight";
        type = lib.types.int;
        default = 1500;
      };
    };
  };

  config = mkIfEnableAnd cfg.enable {
    boot.initrd.systemd = {
      storePaths = [
        runner
        skeleton
      ];

      contents = {
        "/etc/repart-data.d/10-nix-rw.conf".text = ''
          [Partition]
          Type=linux-generic
          Label=${layout.labels.storeRw}
          Format=${layout.rwFsType}
          SizeMinBytes=${cfg.nixRw.minSize}
          SizeMaxBytes=${cfg.nixRw.maxSize}
          Weight=500
          CopyFiles=${skeleton}:/
        '';
        "/etc/repart-data.d/20-home.conf".text = ''
          [Partition]
          Type=home
          Label=${layout.labels.home}
          Format=${cfg.home.fsType}
          Weight=${toString cfg.home.weight}
        '';
      };

      # runs after the system disk is done, before the root fs is assembled
      services.repart-data = {
        description = "partition the data disk";
        wantedBy = [ "initrd.target" ];
        after = [ "systemd-repart.service" ];
        requires = [ "systemd-repart.service" ];
        before = [
          "initrd-root-fs.target"
          "initrd-fs.target"
        ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe runner;
        };
      };
    };

    # no data disk : /home stays on tmpfs
    fileSystems."/home" = {
      device = "/dev/disk/by-partlabel/${layout.labels.home}";
      inherit (cfg.home) fsType;
      options = [
        "defaults"
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };
  };
}
