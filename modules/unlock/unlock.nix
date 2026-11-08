# unlock.nix
# options shared by all the files of the unlock module
{
  mkModule,
  mkOptions,
  meta,
  moduleName,
  self,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {
    configDir = mkPathOption "unlock configuration directory" "/etc/${meta.name}/${moduleName}";

    nixpkgs = lib.mkOption {
      description = "How to fetch the nixpkgs sources";
      type =
        with lib.types;
        either
          # follow official channels
          (submodule {
            options.channel = mkStrOption "branch to use" "nixos-unstable";
          })
          # download from github releases
          (
            submodule {
              options.url = mkStrOption "nixpkgs git repository url" "https://github.com/nixOS/nixpkgs.git";
              options.branch = mkStrOption "branch to use" "nixos-unstable";
            }
          );
      # default to channels : faster, and contains the command not found helper
      default = {
        channel = "nixos-unstable";
      };
    };
    # Pin NonOS to the meta version
    ${meta.name} = {
      url = mkStrOption "the url to pin ${meta.name} to." meta.flake_url;
    };
  };

  config = mkIfEnable {
    # prevent conflicts with image module
    assertions = [
      {
        # we don't want image to be enabled when adding unlock
        # this is meant for non-atomic updates
        assertion = let
          optionTrue = name: lib.attrByPath (lib.splitString "." name) false config;
        in
        !((optionTrue "${meta.name}.image.enable") || (optionTrue "image.repart.enable"));
        message = "${moduleName} conflicts with image, only use one at a time";
      }

    # make sure the configuration path exist
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0755 root root - -"
    ];
  };
}
