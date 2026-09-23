# flake part module for building test configurations
{
  self,
  inputs,
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

  imageSystem =
    let
      system = "x86_64-linux";
      nonOS = self;
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        nonOS.nixosModules.image
        {
          networking.hostName = "image";
          nixpkgs.hostPlatform = system;
          nonOS.image = {
            enable = true;
            repart.var.priority = 2000;
            # device = "/dev/nvme0n1";
          };
          boot.loader.grub.enable = false;
          services.getty.autologinUser = "root";
          users.users.root.initialPassword = "";
        }
      ];
      specialArgs = {
        inherit nonOS;
      };
    };

  run-qemu =
    {
      pkgs,
      image,
    }:
    with pkgs;
    writeShellScriptBin "repart-image-qemu" ''
      set -euo pipefail
      DISK_IMAGE="demo-disk.raw"
      if [[ ! -f "$DISK_IMAGE" ]]; then
        cp ${image}/image.raw "$DISK_IMAGE"
        chmod +w "$DISK_IMAGE"
        ${qemu}/bin/qemu-img resize -f raw "$DISK_IMAGE" "+10G"
      fi

      ${lib.getExe qemu} \
        -smp 4 \
        -m 2048 \
        --enable-kvm \
        -cpu host \
        -bios "${OVMF.fd}/FV/OVMF.fd" \
        -hda "$DISK_IMAGE" \
        -serial stdio \
        -display gtk
    '';
in
{
  # expose our configuration
  flake.nixosConfigurations = {
    demo = imageSystem;
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages = {
        image = run-qemu {
          inherit pkgs;
          image = imageSystem.config.system.build.images.raw-efi;
        };
        #  # default = self.packages.${system}.run-image;
      };
    };
}
