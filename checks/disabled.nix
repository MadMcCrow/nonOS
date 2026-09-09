# disabled.
sources: _:
let
  nonOS = import sources.nonOS;
in
{
  imports = [ nonOS.nixosModules.default ];
  config = {
    networking.hostName = "disabled";
    nixpkgs.hostPlatform = "x86_64-linux";
    nonOS.enable = false;
  };
}
