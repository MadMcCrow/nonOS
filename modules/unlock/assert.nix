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
  optionTrue = name: lib.attrByPath (splitString "." name) false config;
in
{
  config.assertions = [
    {
      # we don't want image to be enabled when adding unlock
      # this is meant for non-atomic updates
      assertion = (optionTrue "nonOS.image.enable") || (optionTrue "image.repart.enable");
      message = "unlock conflicts with image, only use one at a time";
    }
  ];
}
