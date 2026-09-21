# nix-store.nix
# nix store is in an overlay fs
# This means we have to handle the read-only filesystem
# as well as the writable one.
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
  options =
    with lib;
    mkOptions {
      writable = {
        device = mkOption {
          default = null;
          description = ''
            partition to mount as writable nix-store.
            If null, it's deactivated.
            It must be a block device, so nfs drives won't work.
            (but SCSI would).
          '';
          type = with types; nullOr str;
        };
      };
    };
  config = mkIfEnable {
    # the image read-only squashfs store
    fileSystems =
      if cfg.writable.device != null then
        {
          "/nix/.rw-store" = {
            device = cfg.nixStore.device;
            fsType = "btrfs";
            neededForBoot = true;
          };
          # the merged, writable view Nix actually sees at /nix/store
          "/nix/store" = {
            fsType = "overlay";
            overlay = {
              lowerdir = [ "/nix/.ro-store" ];
              upperdir = "/nix/.rw-store/upper";
              workdir = "/nix/.rw-store/work";
            };
            # TODO : make this mount later
            neededForBoot = true;
          };
        }
      else
        {
          "/nix/store" = {
            fsType = "squashfs";
            device = "/nix/.ro-store";
            options = [
              "bind"
              "ro"
            ];
          };
        };

    # enable nix if we have a writable nix-store
    nix.enable = if cfg.writable.device != null then lib.mkForce true else lib.mkDefault false;
  };
}
