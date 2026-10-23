# assert.nix
# make sur you don't use incompatible modules options
{
  mkModule,
  mkOptions,
  meta,
  self,
  moduleName,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
let
  # helper to parse options from other modules that may not be declared
  optionTrue = name : lib.attrByPath (splitString "." name) false config;
in
{
  config.assertions = [
        {
          # we don't want image to be enabled when adding unlock
          # this is meant for non-atomic updates
          assertion = (optionTrue "nonOS.image.enable") || (optionTrue "image.repart.enable");
          message = "unlock conflicts with image, only use one at a time";
        }
        {
          # we can't use both backend at once.
          # changing backend might cause issues.
          # TODO: add a warning at eval if the backend changes from the currently running OS.
           assertion = config.${moduleName}.npins.enable != config.${moduleName}.tack.enable;
           message = "only one of tack and npins can be used as a backend for the source pinning";
        }
      ];
}
