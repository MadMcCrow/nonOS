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
  inherit (config.system.image) version;
  rwMount = "/nix/.rw-store";

  # empty dirs copied into nix-rw at creation
  skeleton = pkgs.runCommand "nix-rw-skeleton" { } ''
    mkdir -p $out/{upper,work,var,tmp}
    chmod 1777 $out/tmp
  '';

  # TODO: make this an option
  roMount = "/nix/.ro-store";
  rwMount = "/nix/.rw-store";

   # runs in the initrd, decides at boot
   assemble = pkgs.writeShellApplication {
     name = "nix-store-assemble";
     runtimeInputs = [
       config.boot.initrd.systemd.package
       pkgs.util-linux
       pkgs.coreutils
     ];
     text = ''
       root=/sysroot
       mkdir -p "$root/nix/store" "$root${rwMount}" "$root/nix/var/nix"
       if [ -b "${cfg.device}" ] \
         && mount -t ${layout.rwFsType} -o noatime "${cfg.device}" "$root${rwMount}"; then
         mkdir -p "$root${rwMount}"/{upper,work,var,tmp}
         mount -t overlay overlay \
           -o "lowerdir=$root${roMount},upperdir=$root${rwMount}/upper,workdir=$root${rwMount}/work" \
           "$root/nix/store"
         mount --bind "$root${rwMount}/var" "$root/nix/var/nix"
         echo "NONOS-STORE=rw"
       else
         mount --bind "$root${roMount}" "$root/nix/store"
         echo "NONOS-STORE=ro"
       fi
     '';
   };

   # nix only runs if the writable store is mounted
   needsRw.unitConfig.ConditionPathIsMountPoint = rwMount;


in
{
  options = (with self.lib.options); mkOptions {
    ro-label = mkStrOption  "store slot label for THIS version" "nix-store_${config.system.image.version}";

    writable = {
      # file inside the squashfs, read at first boot
      registration = mkStrOption "nix DB registration file" ".nonos-registration";
      #
      device = mkPathOption "block device for the writable store" "/dev/disk/by-partlabel/${layout.labels.storeRw}";
      #
      fsType = mkFsOption "filesystem type for the writable store" "ext4";
    };
  };

  config = mkIfEnable {

    fileSystems = {
      # only the ro slot is static
    "${roMount}" = {
          device = "/dev/disk/by-partlabel/${cfg.ro-label}";
          fsType = "squashfs";
          options = [ "ro" ];
          neededForBoot = true;
        };

      # units exist, but only start when the rw store is there
      nix.enable = true;


    systemd.services = lib.mkIf cfg.writable.enable {
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
      };
    };

    #
    # registration data for the ro store (not part of toplevel : no cycle)
    image.repart.partitions.nix-store.contents."/${layout.registration}".source = let
        closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
   in
   "${closureInfo}/registration";
  };
}
