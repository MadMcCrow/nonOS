{
  modConfig,
  mkOptions,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  # options = mkOptions { };
  config = mkIfEnable {
    system.image.id = "nonOS";
  };
}
