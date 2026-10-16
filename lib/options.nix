# helper functions for often used patterns in options
{ lib, ... }: rec {
  # types for options
  types = {
    # helper to allow "auto" or another type;
    autoOr = type: lib.types.either (lib.types.enum [ "auto" ]) type;

    # a size, as a string
    size = lib.types.mkOptionType {
      name = "size";
      description = "a size in bytes (e.g. 4096, 16K, 512M, 32G)";
      check = value: with builtins; isString value && match "[0-9]+[KMGTP]?" value != null;
    };

    duration = lib.types.mkOptionType {
      name = "duration";
      description = "a duration (e.g. 10s, 10m, 200ms, 1h)";
      check = value: with builtins; isString value && match "[0-9]+[(ms)msh]?" value != null;
    };

    fsType =
      let
        supportedTypes = [
          "btrfs"
          "ext4"
          "ext2"
          "f2fs"
          "xfs"
        ];
      in
      (lib.types.enum supportedTypes)
      // {
        description = "filesystem type. currently supported are: ${lib.strings.concatStringsSep "," supportedTypes}.";
      };
  };

  # helper for making custom typed option easily
  mkTypedOption =
    type: description: default:
    lib.mkOption {
      inherit type description default;
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

  # any enum :
  mkEnumOption =
    description: enum: default:
    mkTypedOption (lib.types.enum enum) description default;
}
