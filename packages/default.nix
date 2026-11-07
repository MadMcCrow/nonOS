# flake part module for packages
args@{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    with lib;
    with builtins;
    {
      packages =
        with self.lib.packages;
        genPkgs {
          inherit pkgs args;
          paths = listNixPkgs ./.;
        };

      # add an update script
      apps.update =
        with pkgs;
        let
          # update pinned sources
          script = writeShellScriptBin "update-pins" ''
            root=$(${getExe git} rev-parse --show-toplevel)
            ${getExe npins} -d "$root/packages/_npins" update
          '';
        in
        {
          type = "app";
          program = "${getExe script}";
        };
    };
}
