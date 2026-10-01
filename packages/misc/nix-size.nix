# simple shell application to know the closure size of a package
{
  writeShellApplication,
  nix,
  ...
}:
writeShellApplication {
  name = "nix-size";
  runtimeInputs = [ nix ];
  text = ''
    result=$(nix build --no-link --print-out-paths "nixpkgs#$1")
    nix path-info -Sh "$result"
  '';
  runtimeEnv = {
    # make sure nix is flake and command ready :
    "NIX_CONFIG" = "experimental-features = nix-command flakes";
  };
}
