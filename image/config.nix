# image/config.nix
# the default image config
# TODO : provide other images
{
  lib,
  nonOS,
  ...
}:
{
  # import all necessary modules
  imports = with nonOS.nixosModules; [
    image
    desktop
    audio
    storage
    customization
  ];
  # actual config
  config = {
    nonOS = {
      # support AMD hardware to get correct display
      desktop.graphics.amd.enable = true;
      image.slot.size = "4G";
      storage = {
        automount = {
          "nonOS-home" = {
            mountPoint = "/home";
            fsType = "auto";
          };
        };
          zfs.enable = false;
          bcachefs.enable = true;
        };
      };
  };
}
