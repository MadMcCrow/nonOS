# image.nix
# nix store is in an overlay fs
# This means we have to handle the read-only filesystem
# as well as the writable one.
{
  modConfig,
  inputs,
  ...
}:
{ config, pkgs, ... }:
with (modConfig config);
{
  options = mkOptions {
    update = {
      staging = lib.mkOption {
        description = "path to staging update";
        default = "/var/lib/fw-upload/staging";
        type = lib.types.path;
      };
    };
  };

  config = mkIfEnable {

  systemd.sysupdate = {
    enable = true;

    transfers =
      let
        commonSource = {
          Type="regular-file";
          Path="/var/lib/fw-upload/staging";
        };
        Transfer.Verify = "yes";
      in
      {
        "10-nix-store" = {
          Source = commonSource // {
            MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw.xz" ];
          };

          Target = {
            InstancesMax = 2;
            Path = "auto";
            MatchPattern = "nix-store_@v";
            Type = "partition";
            MatchPartitionType = "linux-generic";
            ReadOnly = "yes";
          };

          inherit Transfer;
        };

        "20-boot-image" = {
          Source = commonSource // {
            MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];
          };
          Target = {
            InstancesMax = 2;
            MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];

            Mode = "0444";
            Path = "/EFI/Linux";
            PathRelativeTo = "boot";

            Type = "regular-file";
          };
          inherit Transfer;
        };
      };
  };
  };
}
