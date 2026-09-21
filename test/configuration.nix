{ nonOS, ... }: {
  imports = [
    nonOS.nixosModules.image
  ];
  config = {
    networking.hostName = "image";
    nixpkgs.hostPlatform = "x86_64-linux";
    nonOS.image = {
      enable = true;
      filesystems.var.priority = 2000;
      # device = "/dev/nvme0n1";
    };
    boot.loader.grub.enable = false;
    services.getty.autologinUser = "root";
    users.users.root.initialPassword = "";
  };
}
