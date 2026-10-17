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
  utils,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # all zfs compatible kernels
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;

  # most recent one
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
      zfs.allowHibernation = true;
      supportedFilesystems.zfs = true;
    };
    # make sure everything is available
    services.zfs = {
      autoScrub.enable = true;
      trim.enable = true; # is already true by default
      autoSnapshot.enable = true; # only work on dataset marked with snapshots
      autoReplication.enable = true; # replication of snapshots
      expandOnBoot = "all";
    };
    # add our zfs encryption tool
    environment.systemPackages =
      lib.optional cfg.encryption.enable
        self.packages.${pkgs.stdenv.hostPlatform.system}.zfs-encrypt;
  };
}
