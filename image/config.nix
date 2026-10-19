# image/config.nix
# the default image config
{
  lib, nonOS, ...
}:

     inherit system;
     modules =
    (with self.nixosModules; [
       image
       desktop
       audio
       storage
       customization
    ]) ++ [
       {
         nonOS = {
           storage.zfs.enable = true;
           desktop.graphics.amd.enable = true;
           image.slot.size = "4G";
           storage.automount = {
             "nonOS-home" = {
               mountPoint = "/home";
               fsType = "auto";
             };
           };
         };
       }
     ];
   }
