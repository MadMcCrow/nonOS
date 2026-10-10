# update.nix
# A/B updates with systemd-sysupdate, and the bundle to upload
{
  modConfig,
  mkOptions,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (modConfig config);
let
  inherit (mod) layout;
  inherit (config.system.image) id version;
  inherit (config.system.boot.loader) ukiFile;
in
{
  options = mkOptions {
    target.disk = lib.mkOption {
      description = ''
        disk holding the store slots. "auto" may fail with a tmpfs root :
        prefer /dev/disk/by-id/nvme-...
      '';
      default = "auto";
      type = lib.types.str;
    };
  };

  config = mkIfEnable {
    # what you upload : compressed store slot + UKI
    system.build.updateBundle =
      pkgs.runCommand "nonos-update-${version}" { nativeBuildInputs = [ pkgs.xz ]; }
        ''
          mkdir -p $out
          src=$(echo ${config.system.build.image}/*nix-store*.raw)
          xz -T0 -c "$src" > $out/${id}_${version}.nix-store.raw.xz
          cp ${config.system.build.uki}/${ukiFile} $out/
        '';

    systemd.sysupdate = {
      enable = true;
      transfers =
        let
          source = {
            Type = "regular-file";
            Path = layout.stagingDir;
          };
          Transfer.Verify = "no"; # TODO : sign bundles, then set to yes
        in
        {
          "10-nix-store" = {
            Source = source // {
              MatchPattern = [ "${id}_@v.nix-store.raw.xz" ];
            };
            Target = {
              InstancesMax = 2;
              Path = cfg.target.disk;
              MatchPattern = "nix-store_@v";
              Type = "partition";
              MatchPartitionType = "linux-generic";
              ReadOnly = "yes";
            };
            inherit Transfer;
          };
          "20-boot-image" = {
            Source = source // {
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

    systemd.tmpfiles.rules = [ "d ${layout.stagingDir} 0750 root root -" ];
  };
}
