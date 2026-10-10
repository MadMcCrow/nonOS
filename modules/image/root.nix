# root.nix
# tmpfs root, boot partition, initrd modules
{
  modConfig,
  mkOptions,
  ...
}:
{
  config,
  ...
}:
with (modConfig config);
{
  config = mkIfEnable {
    fileSystems = {
      "/" = {
        fsType = "tmpfs";
        options = [
          "mode=0755"
          "size=50%"
        ];
      };
      "/boot" = {
        device = "/dev/disk/by-partlabel/${mod.labels.boot}";
        fsType = "vfat";
      };
    };

    boot.initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "sd_mod"
      "xhci_pci"
      "usb_storage"
      "squashfs"
      "overlay"
      "btrfs"
      "ext4"
      "vfat"
    ];
  };
}
