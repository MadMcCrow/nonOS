# build and run an image in a vm with QEMU
{
  lib,
  writeShellApplication,
  ...
}:
let
  size = "10G";
in
# run an image inside qemu
# just a function
configuration:
let
  image = configuration.config.system.build.image;
  inherit (configuration.config.system.image) version;
in
writeShellApplication {
  name = "image-qemu-${version}";
  runtimeInputs = [
    qemu
  ];
  runtimeEnv = {
    DISK_IMAGE = "demo-disk.raw";
  };
  text = ''
    set -euo pipefail
    DISK_IMAGE="demo-disk.raw"
    rm "$DISK_IMAGE" && true
    cp ${image}/image_${version}.raw "$DISK_IMAGE"
    chmod +xw "$DISK_IMAGE"
    qemu-img resize "$DISK_IMAGE" +${size}
    qemu \
     -smp 4 \
     -m 4096 \
     --enable-kvm \
     -cpu host \
     -bios "${OVMF.fd}/FV/OVMF.fd" \
     -drive file="$DISK_IMAGE",format=raw \
     -serial stdio \
     -display gtk
  '';
}
