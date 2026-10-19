# flake part module for pre-commit
{
  withSystem,
  inputs,
  ...
}:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      pre-commit.settings.hooks = lib.mkIf false {
        nixpkgs-fmt.enable = true;
        # TODO :
        update-flake = {
          enable = false;
          name = "update-packages";
          description = "Run MyTool on all files in the project";
          files = "\\.mtl$";
          entry = "${pkgs.my-tool}/bin/mytoolctl";
        };
      };
    };
}
