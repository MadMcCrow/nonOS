# flake part module for building test configurations
{
  self,
  inputs,
  lib,
  ...
}:
let
  # QEMU VM configuration
  mkVM = _: {
    imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
    config = {
      virtualisation.memorySize = 4096;
      virtualisation.cores = 4;
    };
  };

  # build an image
  systemConfig =
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
              enable = true;
              repart.var.priority = 2000;
            };
            debug.root.enable = true;
          };
        }
      ];
      specialArgs = {
        inherit nonOS;
      };
    });

  systemImage = args: (systemConfig args).config.system.build.image;

  resizeImage =
    {
      pkgs,
      image ? (systemImage { }),
      size ? "10G",
    }:
    with pkgs;
    runCommand "system-image-${size}"
      {
        nativeBuildInputs = [ qemu ];
      }
      ''
        mkdir -p $out
        cp ${image}/image.raw $out/image.raw
        chmod +xw $out/image.raw
        qemu-img resize $out/image.raw +${size}
      '';

  # run an image inside qemu
  runQemu =
    {
      pkgs,
      image ? (resizeImage { inherit pkgs; }),
    }:
    with pkgs;
    writeShellScriptBin "repart-image-qemu" ''
      set -euo pipefail
       DISK_IMAGE="demo-disk.raw"
       rm "$DISK_IMAGE" && true
       cp ${image}/image.raw "$DISK_IMAGE"
       chmod +w "$DISK_IMAGE"
      ${lib.getExe qemu} \
        -smp 4 \
        -m 2048 \
        --enable-kvm \
        -cpu host \
        -bios "${OVMF.fd}/FV/OVMF.fd" \
        -drive file="$DISK_IMAGE",format=raw \
        -serial stdio \
        -display gtk
    '';
in
{
  # expose our configuration
  flake.nixosConfigurations = {
    demo = systemConfig { };
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages = rec {
        raw-image = systemImage { inherit system; };
        expanded-image = resizeImage {
          inherit pkgs;
          image = raw-image;
        };
        run-image = runQemu {
          inherit pkgs;
          image = expanded-image;
        };
      };
    };
}
