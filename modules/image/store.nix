# store.nix
# /nix/store = overlay(ro squashfs slot, rw btrfs on the data disk)
{
  modConfig,
  mkOptions,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
let
  inherit (mod) layout;
  inherit (cfg) writable;
  inherit (config.system.image) version;
  roMount = if writable.enable then "/nix/.ro-store" else "/nix/store";
  rwMount = "/nix/.rw-store";
in
{
  options = mkOptions {
    writable = {
      enable = lib.mkEnableOption "writable overlay on top of the read-only store" // {
        default = true;
      };
      device = lib.mkOption {
        description = "block device for the writable store";
        type = lib.types.nonEmptyStr;
        default = "/dev/disk/by-partlabel/${layout.labels.storeRw}";
      };
    };
  };

  config = mkIfEnable {
    fileSystems = lib.mkMerge [
      {
        "${roMount}" = {
          device = "/dev/disk/by-partlabel/${layout.labels.storeRo}";
          fsType = "squashfs";
          options = [ "ro" ];
          neededForBoot = true;
        };
      }
      (lib.mkIf writable.enable {
        "${rwMount}" = {
          inherit (writable) device;
          fsType = layout.rwFsType;
          options = [ "noatime" ];
          neededForBoot = true;
        };
        "/nix/store" = {
          fsType = "overlay";
          overlay = {
            lowerdir = [ roMount ];
            upperdir = "${rwMount}/upper";
            workdir = "${rwMount}/work";
          };
          neededForBoot = true;
        };
        # persistent nix DB (root is tmpfs)
        "/nix/var/nix" = {
          device = "${rwMount}/var";
          fsType = "none";
          options = [ "bind" ];
          depends = [ rwMount ];
        };
      })
    ];

    nix.enable = if writable.enable then lib.mkForce true else lib.mkDefault false;

    systemd.services = lib.mkIf writable.enable {
      # register ro-store paths in the persistent nix DB, once per version
      nix-load-db = {
        description = "register read-only store paths in the nix DB";
        wantedBy = [ "multi-user.target" ];
        before = [
          "nix-daemon.service"
          "nix-daemon.socket"
        ];
        unitConfig.RequiresMountsFor = [ "/nix/var/nix" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ config.nix.package ];
        script = ''
          marker="/nix/var/nix/registered-${version}"
          [ -e "$marker" ] && exit 0
          nix-store --load-db < ${roMount}/${layout.registration}
          touch "$marker"
        '';
      };
      # builds go to the data disk, not to RAM
      nix-daemon.environment.TMPDIR = "${rwMount}/tmp";
    };
  };
}
