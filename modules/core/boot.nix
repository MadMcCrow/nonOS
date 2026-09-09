# boot.nix
# define how nonOS boots
# customization.nix
# replace nixOS by nonOS in the various config files
{modConfig, mkOptions, inputs, ...}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options = mkOptions {
    # enable secureboot
    secureboot.enable = mkEnableOption "secureboot" // {
      default = true;
    };
    # yubikey,onlykey, etc..
    fido.enable = mkEnableOption "FIDO2 : https://nixos.org/manual/nixos/stable/#sec-luks-file-systems-fido2";
  };

  config = mkIfEnable {
    boot = {
      initrd.systemd = {
        enable = true;
        fido2.enable = cfg.fido.enable;
      };
      tmp.cleanOnBoot = true;
      loader = {
        systemd-boot.enable = !cfg.secureboot.enable;
        grub.enable = false;
      };
      lanzaboote = {
        inherit (cfg.secureboot) enable;
        pkiBundle = "${cfg._dir}/secureboot";
        configurationLimit = 5;
      };
      plymouth.enable = true;
      consoleLogLevel = 3;
    };

    environment = {
      defaultPackages =
        with pkgs;
        [
          openssl
          dnsutils
          sbctl
          # tpm-luks -> removed due to lack of maintenance
          tpm2-tss
          nmap
        ]
        ++ (optionals cfg.fido.enable [ libfido2 ]);
    };

    hardware = {
      # we could include both microcodes
      # but the hardware detection can give you the correct param
      # cpu.amd.updateMicrocode = true;
      # cpu.intel.updateMicrocode = true;
      # we just need this to be enabled :
      enableRedistributableFirmware = true;
      firmware = [ pkgs.linux-firmware ];
    };
  };
}
