# flake part module for building test configurations
{
  self,
  inputs,
  lib,
  ...
}:
let
  # build an image
  mkImageSystem =
    {
      system ? "x86_64-linux",
      nonOS ? self,
    }:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        nonOS.nixosModules.image
        nonOS.nixosModules.desktop
        nonOS.nixosModules.audio
        nonOS.nixosModules.customization
        {
          nonOS = {
            desktop.graphics.amd.enable = true;
            image.slot.size = "3G";
            image.filesystems = {
              "nonOS-home" = {
                mountPoint = "/home";
                fsType = "btrfs";
              };
            };
          };
        }
      ];
      specialArgs = {
        inherit nonOS;
      };
    });
in
{
  # expose our configuration
  flake.nixosConfigurations = {
    demo = mkImageSystem { };
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    with pkgs;
    let
      mkSizedImage =
        {
          extraArgs ? { },
          size ? "10G",
        }:
        let
          system = mkImageSystem extraArgs;
          image = system.config.system.build.image;
          inherit (system.config.system.image) version;
        in
        runCommand "system-image-${size}"
          {
            nativeBuildInputs = [ qemu ];
          }
          ''
            mkdir -p $out
            cp ${image}/image_${version}.raw $out/image.raw
            chmod +xw $out/image.raw
            qemu-img resize $out/image.raw +${size}
          '';

      # run an image inside qemu
      runQemu =
        image:
        writeShellScriptBin "repart-image-qemu" ''
          set -euo pipefail
           DISK_IMAGE="demo-disk.raw"
           rm "$DISK_IMAGE" && true
           cp ${image}/image.raw "$DISK_IMAGE"
           chmod +w "$DISK_IMAGE"
          ${lib.getExe qemu} \
            -smp 4 \
            -m 4096 \
            --enable-kvm \
            -cpu host \
            -bios "${OVMF.fd}/FV/OVMF.fd" \
            -drive file="$DISK_IMAGE",format=raw \
            -serial stdio \
            -display gtk
        '';

      # install image to a disk device.
      installToDisk =
        {
          extraArgs ? { },
        }:
        let
          system = mkImageSystem extraArgs;
          image = system.config.system.build.image;
          inherit (system.config.system.image) version;
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
    in
    lib.mkIf stdenv.hostPlatform.isLinux {
      packages = {
        image-raw = (mkImageSystem { inherit system; }).config.system.build.image;
        image-run = runQemu (mkSizedImage {
          size = "10G";
        });
        image-install = installToDisk { };
      };
    };
}
