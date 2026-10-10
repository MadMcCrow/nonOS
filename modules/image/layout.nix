# layout.nix
# shared constants. Single source of truth. Other files read ONLY this.
{
  modConfig,
  mkModOptions,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
let
  mkStrOption =
    description: default:
    lib.mkOption {
      inherit description default;
      type = lib.types.nonEmptyStr;
      readOnly = true;
    };
  mkSizeOption =
    description: default:
    lib.mkOption {
      inherit description default;
      type = lib.types.nonEmptyStr;
    };
in
{
  options = mkModOptions {

    espSize = mkSizeOption "mkSizeOption of the ESP" "512M";
    slotSize = mkSizeOption "mkSizeOption of each store slot" "4G";

    # writable format
    rwFsType = lib.mkOption  {
      description = "filesystem format of the writable store";
      type = lib.types.enum ["btrfs" "ext4" "ext2" "f2fs" "xfs"];
      default = "btrfs";
    }

    labels = {
      boot = mkStrOption "ESP label" "boot";
      storeRo = mkStrOption "store slot label for THIS version" "nix-store_${config.system.image.version}";
      storeEmpty = mkStrOption "label of a never-written slot" "_empty";
      storeRw = mkStrOption "writable store label" "nix-rw";
      var = mkStrOption "var label" "var";
      home = mkStrOption "home label" "home";
    };

    # file inside the squashfs, read at first boot
    registration = mkStrOption "nix DB registration file" ".nonos-registration";

    # written by upload.nix, read by update.nix
    stagingDir = mkSizeOption "verified update files" "/var/lib/fw-upload/staging";
  };
}
