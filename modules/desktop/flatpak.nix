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
let
  users = filter (u: u.isNormalUser) (attrValues config.users.users);
in
{
  # interface
  options = mkOptions {
    flatpak = {
      enable = lib.mkEnableOption "flatpak support" // {
        default = true;
      };
      systemDir = lib.mkOption {
        description = "path to bind mount to /var/lib/flatpak";
        type = with lib.types; nullOr path;
        default = null;
      };
      userDir = lib.mkOption {
        description = "path to bind mount to ~/.var/app and ~/.local/share/flatpak";
        type = with lib.types; nullOr path;
        default = null;
      };
    };
  };

  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  # implementation
  config = mkIfEnableAnd cfg.enable {
    filesystem =
      let
        mkMount =
          source: target:
          lib.optionalAttr (source != null) {
            "${target}" = {
              device = "${source}";
              fsType = "none";
              options = [ "bind" ];
            };
          };
      in
      lib.mkMerge (
        [
          (mkMount cfg.systemDir "/var/lib/flatpak")
        ]
        ++ (lib.optionals cfg.userDir (
          lib.flatten (
            map (u: [
              (mkMount "${cfg.userDir}/${u.name}/appdata" "${u.home}/.var/app")
              (mkMount "${cfg.userDir}/${u.name}/appconfig" "${u.home}/.local/share/flatpak")
            ]) users
          )
        ))
      );

    services.flatpak = {
      enable = true;

      update = {
        onActivation = true;
        auto = {
          enable = true;
          onCalendar = "weekly"; # Default value
        };
      };
    };

    # set tag for version
    system.nixos.tags = [ "Flatpak" ];

    # create bound folders if needed
    systemd.tmpfiles.rules =
      let
        mkUserTmpDir = u: [
          "d ${cfg.userDir}/${u.name}/appdata   0755 ${u.name} ${u.name} -"
          "d ${cfg.userDir}/${u.name}/appconfig 0755 ${u.name} ${u.name} -"
        ];
      in
      (lib.optionals (cfg.systemDir != null) [ "d ${cfg.systemDir} 0755 root root -" ])
      ++ (lib.optionals (cfg.userDir != null) (lib.flatten (map mkUserTmpDir users)));

    xdg.portal.enable = true;
  };
}
