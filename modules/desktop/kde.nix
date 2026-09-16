# kde.nix
# enable the kde desktop
{
  modConfig,
  mkOptions,
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
  # interface
  options = mkOptions { };

  # implementation
  config = mkIfEnable {
    # set tag for version
    system.nixos.tags = [ "Desktop" ];

    # enable KDE :
    services = {
      desktopManager.plasma6.enable = true;
      displayManager.sddm = {
        enable = true;
        autoNumlock = true;
        # this prevents issues with nvidia drivers
        wayland.enable = !(builtins.any (x: x == "nvidia") config.services.xserver.videoDrivers);
      };

      xserver = {
        enable = true;
        # remove xterm
        desktopManager.xterm.enable = false;
        excludePackages = [ pkgs.xterm ];
      };
    };

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-lgc-plus
      jetbrains-mono
    ];

    qt = {
      enable = true;
      platformTheme = "kde";
    };

    # enable tools
    programs = {
      dconf.enable = true;
      kdeconnect.enable = true;
      partition-manager.enable = true;
    };

    # remove useless KDE packages
    environment = {
      plasma6.excludePackages =
        # pkgs can be inside :
        with pkgs.kdePackages; [
          oxygen
          khelpcenter
          plasma-browser-integration
          print-manager
          kio-extras
          kwallet
          kwallet-pam
          kate
          okular
        ];

      systemPackages =
        with pkgs;
        [
          papirus-icon-theme
          kdePackages.kcalc
        ]
        # TODO : enable custom themes and widgets
        ++ lib.optionals false (
          with nonpkgs;
          [
            plasma-vapor-theme
            plasma-drawer
          ]
        );
    };
  };
}
