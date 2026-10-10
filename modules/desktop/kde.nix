# kde.nix
# enable the kde desktop
{
  modConfig,
  mkOptions,
  inputs,
  self,
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
  options = mkOptions {
    # not enabled by default
    extras.enable = lib.mkEnableOption "extra KDE apps";
  };

  # implementation
  config = mkIfEnable {
    # set tag for version
    system.nixos.tags = [ "KDE" ];

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

    # remove unecessary KDE packages (minimal kde experience)
    environment.plasma6.excludePackages = lib.optionals cfg.extras.enable (
      with pkgs.kdePackages;
      [
        oxygen
        khelpcenter
        plasma-browser-integration
        print-manager
        kio-extras
        kwallet
        kwallet-pam
        kate
        okular
        elisa
      ]
    );

    environment.systemPackages =
      with pkgs;
      with self.packages.${pkgs.stdenv.hostPlatform.system};
      [
        papirus-icon-theme
        kdePackages.kcalc
      ]
      ++ (lib.optional config.services.flatpak.enable kdePackages.discover)
      # TODO : enable custom themes and widgets
      ++ (lib.optionals false [
        plasma-vapor-theme
        plasma-drawer
      ]);
    # should not be necessary
    # xdg.portal.extraPortals = lib.optionals(config.services.flatpak.enable && config.xdg.portal.enable) with pkgs; [xdg-desktop-portal-kde xdg-desktop-portal-shana];
  };
}
