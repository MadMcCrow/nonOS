# zfs.nix
# Support zfs filesystem
{
  mkModule,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # same logic as srvOS
  # https://github.com/nix-community/srvos/blob/2fa72cea3d3d15b104f3c69de18316ef575bc837/nixos/mixins/latest-zfs-kernel.nix
  isUnstable = config.boot.zfs.package == pkgs.zfs_unstable;
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (
      (!isUnstable && !kernelPackages.zfs.meta.broken)
      || (isUnstable && !kernelPackages.zfs_unstable.meta.broken)
    )
  ) pkgs.linuxKernel.packages;
  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );
in
{
  options = mkOptions {
    enable = lib.mkEnableOption "ZFS filesystem support";
    encryption = {
      enable = lib.mkEnableOption "ZFS encryption";
    };
  };
  config = mkIfEnableAnd cfg.enable {
    # use a compatible kernel
    boot = {
      kernelPackages = latestKernelPackage;
      zfs.unsafeAllowHibernation = true;
      supportedFilesystems.zfs = true;
    };

    # make sure everything is available
    services.zfs = {
      autoScrub.enable = true;
      trim.enable = true; # is already true by default
      autoSnapshot.enable = true; # only work on dataset marked with snapshots

      # auto replication needs a user to be specified
      # autoReplication.enable = true; # replication of snapshots

      expandOnBoot = "all";
    };
    # add our zfs encryption tool
    environment.systemPackages =
      lib.optional cfg.encryption.enable
        self.packages.${pkgs.stdenv.hostPlatform.system}.zfs-encrypt;
  };
}
