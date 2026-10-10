# helper functions for often used patterns in options
{lib, ...} :
let
  mkTypedOption = type : description : default : lib.types.mkOption {
     inherit type description default;
  };
rec {

  types = {
    size = lib.types.mkOptionType {
        name = "size";
        description = "a size in bytes (e.g. 4096, 16K, 512M, 32G)";
        check = value: with builtins;
          isString value
          && match "[0-9]+[KMGTP]?" value != null;
      };
  };

  # path
  mkPathOption = mkTypedOption lib.types.path;

  # str
  mkStrOption = mkTypedOption lib.types.str;

  # our size type
  mkSizeOption = mkTypedOption types.size;

  # bool that isn't enable
  mkBoolOption = mkTypedOption lib.types.bool;

  # network port type
  mkPortOption = mkTypedOption lib.types.port;


}
