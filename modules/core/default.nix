# system.nix
# define the update process in NonOS
{
  modConfig,
  inputs,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (modConfig config);
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/profiles/minimal.nix"
  ];

  config = mkIfEnable {
    environment = {
      systemPackages = [ os.pkgs.ostool ];
      defaultPackages = with pkgs; [
        openssl
        dnsutils
        nmap
      ];
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

    programs = {
      # zsh is the far superior shell in my opinion
      zsh.enable = true;
      bash.enable = false;
    };

    services = {
      openssh = {
        enable = true;
        ports = [ 8323 ];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = attrNames config.users.users;
        };
      };
    };

    time = {
      # we default to Paris
      timeZone = "Europe/Paris";
    };

    users = {
      defaultUserShell = pkgs.zsh;
      # enable mutable users if no user is set to admin
      mutableUsers =
        !(any (u: u.group == "wheel" || (any (g: g == "wheel") u.extraGroups)) (
          attrValues config.users.users
        ));
    };
  };
}
