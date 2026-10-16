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
        # add our image module, as-is
        nonOS.nixosModules.image
        nonOS.nixosModules.debug
        nonOS.nixosModules.desktop
        {
          # this may end up being a problem
          networking.hostName = lib.mkDefault "image";
          system.stateVersion = lib.mkDefault "26.11";
          nixpkgs.hostPlatform = system;
          nonOS = {
            image = {
              slot.size = "3G"; # the default image size is 2.6G
              enable = true;
            };
            debug.root.enable = true;
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
        extraArgs ? {},
        size ? "10G"
      }:
      let
        system = (mkImageSystem extraArgs);
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
      {
        pkgs,
        image ? (mkSizedImage {}),
      }:
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

    in
    {
      packages = rec {
        raw-image = mkImageSystem { inherit system; };
        expanded-image = mkSizedImage { size = "10G"; };
        run-image = runQemu {
          inherit pkgs;
          image = expanded-image;
        };
      };
    };
}
