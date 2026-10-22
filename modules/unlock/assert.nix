# assert.nix
# make sur you don't use incompatible modules options
{
  mkModule,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
{
  config.assertions = [
        # we don't want image to be enabled when adding unlock
        { assertion = (config.nonOS.image.enable or true) == false;
          message = "unlock conflicts with image, only use one at a time";
        }
      ];
}
