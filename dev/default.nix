# flake part module for pre-commit
{
  withSystem,
  inputs,
  ...
}:
{
  # import subfolder
  # TODO : use import-tree
  imports = [
    ./pre-commit.nix
    ./shell.nix
    ./treefmt.nix
  ];
}
