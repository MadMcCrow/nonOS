# helper functions for often used patterns in options
{lib, ...} :
let
  mkTypedOption = type : description : default : lib.types.mkOption {
     inherit type description default;
  };
in
rec {

  types = {
    size = lib.types.mkOptionType {
        name = "size";
        description = "a size in bytes (e.g. 4096, 16K, 512M, 32G)";
        check = value: with builtins;
          isString value
          && match "[0-9]+[KMGTP]?" value != null;
      };

    fsType = let
    supportedTypes = ["btrfs" "ext4" "ext2" "f2fs" "xfs"];
    in
    (lib.types.enum supportedTypes) // { description = "filesystem type. currently supported are: ${lib.strings.concatStringsSep "," supportedTypes}."};
  };

  # path
  mkPathOption = mkTypedOption lib.types.path;

  # str
  mkStrOption = mkTypedOption lib.types.str;

  # bool that isn't enable
  mkBoolOption = mkTypedOption lib.types.bool;

  # network port type
  mkIntOption = mkTypedOption lib.types.int;

  # network port type
  mkPortOption = mkTypedOption lib.types.port;

  # our size type
  mkSizeOption = mkTypedOption types.size;

  # our filesystem option
  mkFsOption = mkTypedOption types.fsType;
}
