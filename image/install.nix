# install image to a disk device.
{
  self, lib, writeShellApplication, ...
}:
configuration :
  let
    image = configuration.config.system.build.image;
    inherit (configuration.config.system.image) version;
  in
  writeShellApplication {
    name = "install-${version}";
    runtimeInputs = [
      coreutils
      pv
    ];
    runtimeEnv = {
      IMAGE = "${image}/image_${version}.raw";
    };
    text = ''
      if [ "$#" -ne 1 ]; then
           echo "Usage: $0 /dev/sdX" >&2
           exit 2
         fi
         if [ ! -f "$IMAGE" ]; then
           echo "Image not found: $IMAGE" >&2
           exit 1
         fi
         echo "Writing $IMAGE to $1"
         pv -s "$(stat -c %s "$IMAGE")" "$IMAGE" |
           sudo dd of="$1" bs=4M conv=fsync
         sync
         echo "Installation complete"
    '';
  };
