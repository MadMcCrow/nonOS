# repart.nix
# partition and expand the OS based on a single device
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
{
  options = mkOptions {
    device = lib.mkOption {
      description = "main installation device";
      example = "/dev/nvme0n1";
      type = lib.types.str;
    };
  };

  config = mkIfEnable {
    # root is on tmpfs
    fileSystems."/" = {
      fsType = "tmpfs";
      #options = [ "size=100m" ];
    };
    # add repart to initrd
    boot.initrd.systemd.repart = {
      enable = true;
      inherit (cfg) device;
    };
    # write partitions to create
    systemd.repart.partitions = {
      home = {
        Format = "btrfs";
        Label = "home";
        Type = "home";
        Weight = 2000; # take twice as much space as /var
      };
      var = {
        Format = "btrfs";
        Label = "var";
        Type = "var";
        Weight = 1000;
      };
    };
  };
}
