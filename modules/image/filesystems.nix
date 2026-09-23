# filesystems.nix
# nix store is in an overlay fs
# This means we have to handle the read-only filesystem
# as well as the writable one.
{
  modConfig,
  mkOptions,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/image/repart.nix"
  ];

  config = mkIfEnable {
    fileSystems = {
      # root is on tmpfs
      "/" = {
        fsType = "tmpfs";
        #options = [ "size=100m" ];
      };
      # boot filesystem
      "/boot" = {
        device = "/dev/disk/by-partlabel/boot";
        fsType = "vfat";
      };
      # the image read-only squashfs store
      "/nix/.ro-store" = {
        device = "/dev/disk/by-partlabel/nix-ro-store";
        fsType = "squashfs";
        options = [ "ro" ];
        neededForBoot = true;
      };
      # add our optional filesystems
    };

    image.repart = {
      name = "image";
      partitions = {
        # read-only store image
        nix-ro-store = {
          storePaths = [ config.system.build.toplevel ];
          nixStorePrefix = "/";
          repartConfig = {
            Format = "squashfs";
            Label = "nix-ro-store";
            Minimize = "guess";
            ReadOnly = "yes";
            Type = "linux-generic";
          };
        };
        # EFI partition image
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
            Format = "vfat";
            Label = "boot";
            SizeMinBytes = "200M";
            Type = "esp";
          };
        };
      }; # end of partitions
    };
  };
}
