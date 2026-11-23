# flake part module for pre-commit
{
  withSystem,
  inputs,
  ...
}:
{
  # import subfolder
  imports = [
    ./pre-commit.nix
    ./shell.nix
    ./treefmt.nix
  ];
}
