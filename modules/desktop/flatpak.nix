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
    enable = lib.mkEnableOption "flatpak support" // {
      default = true;
    };
    storage = {
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
  config = lib.mkMerge [
    {
      services.flatpak.enable = lib.mkForce cfg.enable;
    }
    (mkIfEnableAnd cfg.enable {
      fileSystems =
        let
          mkMount = source: target:
            {
              "${target}" = {
                device = "${source}";
                fsType = "none";
                options = [ "bind" ];
              };
            };
        in
        lib.mkMerge (
          [
          ( lib.optionalAttrs (cfg.storage.systemDir != null) (mkMount  cfg.storage.systemDir "/var/lib/flatpak") )
          ] ++ ( lib.optionals (cfg.storage.userDir != null)
              (
                map (u: [
                (mkMount "${cfg.storage.userDir}/${u.name}/appdata" "${u.home}/.var/app")
                (mkMount "${cfg.storage.userDir}/${u.name}/appconfig" "${u.home}/.local/share/flatpak")
              ]) users
            ))
        );

      services.flatpak = {
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
            "d ${cfg.storage.userDir}/${u.name}/appdata   0755 ${u.name} ${u.name} -"
            "d ${cfg.storage.userDir}/${u.name}/appconfig 0755 ${u.name} ${u.name} -"
          ];
        in
        (lib.optionals (cfg.storage.systemDir != null) [ "d ${cfg.storage.systemDir} 0755 root root -" ])
        ++ (lib.optionals (cfg.storage.userDir != null) (lib.flatten (map mkUserTmpDir users)));

      # make sure the xdg portal is enabled
      xdg.portal.enable = true;
    })
  ];
}
