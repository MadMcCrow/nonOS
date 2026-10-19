# treefmt.nix
# specify how to format the nonOS repository
# flake part module for apps
{
  withSystem,
  inputs,
  ...
}:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    rec {
      # treefmt settings
      treefmt = {
        # Used to find the project root
        projectRootFile = "flake.nix";

        programs = {
          autocorrect.enable = true;
          # all the nix formatter
          nixfmt.enable = true;
          statix.enable = true;
          deadnix = {
            enable = false;
            no-lambda-arg = false;
            no-lambda-pattern-names = true;
            no-underscore = true;
          };
          alejandra.enable = true;
          # python formatter
          ruff-check.enable = true;
          ruff-format.enable = true;
          isort.enable = true;
          # shell formatter
          shellcheck.enable = true;
        };
      };
      # add formatter package
      packages.formatter = inputs.treefmt-nix.lib.mkWrapper pkgs treefmt;
    };
}
