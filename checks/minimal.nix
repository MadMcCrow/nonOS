# a minimal host config that should be possible to build
sources: _:
let
  nonOS = import sources.nonOS;
in
{
  imports = [ nonOS.nixosModules.default ];
  config = {
    networking.hostName = "minimal";
    nixpkgs.hostPlatform = "x86_64-linux";
    nonOS = {
      enable = true;
      storage.device = "/dev/nvme0n1";
    };
  };
}
