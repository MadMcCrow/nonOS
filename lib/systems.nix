# modules.nix
{
  self,
  lib,
  nixpkgs,
  ...
}:
with lib;
{
  # create a symlinked output of a nixosSystem
  joinSystemOutputs =
    system:
    let
      name = "system-${system.config.networking.hostName}";
      outputs = with system.config.system.build; [
        diskoScript
        toplevel
        installBootLoader
      ];
    in
    system.pkgs.runCommand name { } ''
      mkdir -p $out
      ${builtins.concatStringsSep "\n" (map (drv: "ln -s ${drv} $out/${builtins.getName drv}") outputs)}
    '';
}
