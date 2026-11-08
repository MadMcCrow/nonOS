# rebuild.nix
# rebuild and try to apply the new config, using nixos-rebuild through system.autoUpgrade
# MAYBE : send a message to the user that the system was updated
{
  mkModule,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  pkgs,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # wrap nixOS rebuild and the update program in one command for manual operation
  rebuild = pkgs.writeShellScriptBin cfg.program.name ''
    ${mod.update.program.package}
    ${pkgs.nixos-rebuild-ng} --no-flake
  '';
in
{
  options = mkOptions {
    program = {
      name = mkStrOption "name of the ${meta.name} (update &) rebuild command" "${meta.name}-rebuild";
      package = mkPkgOption "package to use to update the unlock nixpkgs version" rebuild;
    }
  }
  config = mkIfEnable (
    lib.mkMerge [
      {
        system.autoUpgrade = {
          enable = lib.mkDefault true;
          # no channel to upgrade : the update service moves the pin
          upgrade = lib.mkDefault false;
          # /etc/nixos/flake.nix would win over system.nix without this
          flags = [ "--no-flake" ];
          # dates, operation and allowReboot are left to the user
        };
      }

      # run the update service first
      (lib.mkIf config.system.autoUpgrade.enable {
        systemd.services.nixos-upgrade = {
          wants = [ "${mod.update.service.name}.service" ];
          after = [ "${mod.update.service.name}.service" ];
        };
      })
      {
        environment.systemPackages = [rebuild];
      }
    ]
  );
}
