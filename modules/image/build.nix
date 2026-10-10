# build.nix
# build-time disk image : ESP + store slot A
{
  modConfig,
  mkOptions,
  inputs,
  ...
}:
{
  pkgs,
  lib,
  config,
  ...
}:
with (modConfig config);
let
  inherit (mod) layout;
  # registration data for the ro store (not part of toplevel : no cycle)
  closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
in
{
  imports = [ "${inputs.nixpkgs}/nixos/modules/image/repart.nix" ];

  config = mkIfEnable {
    image.repart = {
      enable = true;
      name = "image";
      # one file per partition : used by the update bundle
      split = true;
      partitions = {
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
            Type = "esp";
            Format = "vfat";
            Label = layout.labels.boot;
            SizeMinBytes = layout.espSize;
            SizeMaxBytes = layout.espSize;
          };
        };
        nix-store = {
          storePaths = [ config.system.build.toplevel ];
          nixStorePrefix = "/";
          contents."/${layout.registration}".source = "${closureInfo}/registration";
          repartConfig = {
            Type = "linux-generic";
            Format = "squashfs";
            Label = layout.labels.storeRo;
            # fixed size : the slot must fit the next version too
            Minimize = "off";
            SizeMinBytes = layout.slotSize;
            SizeMaxBytes = layout.slotSize;
            ReadOnly = "yes";
          };
        };
      };
    };
  };
}
