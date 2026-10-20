# kde.nix
# enable the kde desktop
{
  mkModule,
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
with (mkModule config);
with self.lib.options;
{
  # interface
  options = mkOptions {
    # default to true
    enable = mkBoolOption "enable the KDE desktop environment" true;
    # not enabled by default
    extras.enable = lib.mkEnableOption "extra KDE apps";
    theme.enable = lib.mkEnableOption "custom KDE theme";
    # use the old sddm :
    useLegacySddm = lib.mkEnableOption "sddm instead of plasma-login-manager";
  };

  # implementation
  config = mkIfEnableAnd cfg.enable {
    # set tag for version
    system.nixos.tags = [ "KDE" ];

    # enable KDE :
    services = {
      desktopManager.plasma6.enable = true;
      displayManager = {
        plasma-login-manager.enable = !cfg.useLegacySddm;
        sddm = lib.mkIf cfg.useLegacySddm {
          enable = true;
          autoNumlock = true;
          # this prevents issues with nvidia drivers
          wayland.enable = !(builtins.any (x: x == "nvidia") config.services.xserver.videoDrivers);
        };
      };

      xserver = {
        enable = true;
        # remove xterm
        desktopManager.xterm.enable = false;
        excludePackages = [ pkgs.xterm ];
      };
    };

    fonts.packages = lib.optionals cfg.theme.enable (
      with pkgs;
      [
        noto-fonts
        noto-fonts-lgc-plus
        jetbrains-mono
      ]
    );

    qt = {
      enable = true;
      platformTheme = "kde";
    };

    # enable tools
    programs = {
      dconf.enable = true;
      kdeconnect.enable = true;
      partition-manager.enable = true;
      # Avoid bundling an entire MariaDB installation
      kde-pim.enable = cfg.extras.enable;
    };

    # KDE needs power management backend such as upower
    powerManagement.enable = true;

    # remove unecessary KDE packages (minimal kde experience)
    environment.plasma6.excludePackages =
      with pkgs.kdePackages;
      (lib.optionals (!cfg.extras.enable) [
        khelpcenter
        plasma-browser-integration
        print-manager
        kio-extras
        kio-extras-kf5
        kwallet
        kwallet-pam
        kate
        okular
        elisa
        akonadi
      ])
      ++ (lib.optionals (!cfg.theme.enable) [
        oxygen-icons
        oxygen
        plasma-workspace-wallpapers
      ]);

    environment.systemPackages =
      with pkgs;
      with self.packages.${pkgs.stdenv.hostPlatform.system};
      [
        kdePackages.kcalc
      ]
      ++ (lib.optional config.services.flatpak.enable kdePackages.discover)
      # TODO : enable custom themes and widgets
      ++ (lib.optionals cfg.theme.enable [
        papirus-icon-theme
        plasma-vapor-theme
        plasma-drawer
      ]);
    # should not be necessary
    # xdg.portal.extraPortals = lib.optionals(config.services.flatpak.enable && config.xdg.portal.enable) with pkgs; [xdg-desktop-portal-kde xdg-desktop-portal-shana];
  };
}
