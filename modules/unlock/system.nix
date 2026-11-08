# system.nix
# nixOS entrypoint for building a pinned configuration
# nixos-rebuild (26.05+) finds it through the `nixos-system` NIX_PATH entry,
# or through /etc/nixos/system.nix
{
  mkModule,
  mkOptions,
  meta,
  moduleName,
  self,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
let
  # nonOS is loaded with flake-compat : the default.nix at the root of the repository does it.
  # the store path is referenced here, so the source is part of the system closure.
  thisFlake = "${self}";

  # see https://github.com/NixOS/nixpkgs/blob/60c94fbaddc18ec07ad85829dcef62fdc22907cb/nixos/default.nix
  systemConfiguration = pkgs.writeText "${meta.name}-${moduleName}-system" ''
    let
      nixpkgs = ${cfg.nixpkgs};
      ${meta.name} = import ${thisFlake};
    in
    import "''${nixpkgs}/nixos/lib/eval-config.nix" {
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
    configuration = mkPathOption {
      description = ''
        define the configuration path/entrypoint

        this must be a traditional nixOS (like channel based) configuration file.
        It can use "${meta.name}" in it's arguments, it'll be evaluated to this flake.

        Use a string (e.g. "/etc/${meta.name}/configuration.nix") to read the live file.
        A nix path (e.g. ./configuration.nix) is copied to the store at build time.
      '';
      type = lib.types.path;
    };
    nixPath = mkBoolOption "set the nixPath variable nixos-system to the generated file" true;
    symlink = {
      configDir = mkBoolOption "symlink system.nix to the unlock config directory" true;
      etc.nixos = mkBoolOption "symlink system.nix to /etc/nixos" false;
    };
    # the sources :
    nixpkgs = mkStrOption "nix expression that evaluates to the nixpkgs path, in the system.nix file" "<nixpkgs>";
    ${meta.name} = lib.mkOptions {
      description = "how to fetch ${meta.name}" ;
      type = with lib.types; nullOr str;
      default = null;
    };
  };

  config = mkIfEnable {
    # symlink the config file, for visibility
    systemd.tmpfiles.rules =
      (lib.optional cfg.symlink.configDir "L+ ${mod.configDir}/system.nix - - - - ${systemConfiguration}")
      ++ (lib.optional cfg.symlink.etc.nixos "L+ /etc/nixos/system.nix - - - - ${systemConfiguration}");

    # set nixPath for evaluation
    nix.nixPath = lib.optional cfg.nixPath "nixos-system=${systemConfiguration}";

    # make sure we are not counted as installed by a flake
    nixpkgs.flake = lib.mkForce {
      source = null;
      setNixPath = false;
      setFlakeRegistry = false;
    };
    system.autoUpgrade.flake = lib.mkForce null;
  };
}
