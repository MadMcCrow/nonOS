# system.nix
# nixOS entrypoint for building a pinned configuration
{
  mkModule,
  mkOptions,
  meta,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
let
# make the config file reference this flake
thisFlake = "${self}";

# see https://github.com/NixOS/nixpkgs/blob/60c94fbaddc18ec07ad85829dcef62fdc22907cb/nixos/default.nix
systemConfiguration = pkgs.writeText "${meta.name}-${moduleName}-system" ''
let
  nixpkgs = import ${mod.nixpkgs.import};
  ${meta.name} = ${thisFlake};
in
import "$${nixpkgs}/nixos/lib/eval-config.nix" {
  system = builtins.currentSystem;
  modules = [
    ${cfg.configuration}
    ${meta.name}.nixosModules.${moduleName}
  ];
    specialArgs = {
      inherit ${meta.name};
    };
  }
'';
in
{
  options = mkOptions {
    configuration = lib.mkOption {
      description = ''
        define the configuration path/entrypoint

        this must be a traditional nixOS (like channel based) configuration.
        It can use "${meta.name}" in it's arguments, it'll be evaluated to this flake.
      '';
      type = with lib.types; either path deferredModule;
    };
    nixPath = mkBoolOption "set the nixPath variable nixos-system to the generated file" true;
    symlink = {
      configDir = mkBoolOption "symlink system.nix to ${mod.configDir}" true;
      etc.nixos = mkBoolOption "symlink system.nix to /etc/nixos" false;
    };
  };

  config = mkIfEnable {
    # symlink the config file, for visibility
    systemd.tmpfiles.rules =
    (lib.optional cfg.symlink.configDir "L+ ${mod.configDir}/system.nix - - - - ${systemConfiguration}") ++
    (lib.optional cfg.symlink.etc.nixos "L+ /etc/nixos/system.nix - - - - ${systemConfiguration}");
     # set nixPath for evaluation
     nix.nixPath = lib.optional cfg.nixPath "nixos-system=${systemConfiguration}"
  };

}
