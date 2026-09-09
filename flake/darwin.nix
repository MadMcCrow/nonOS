# support for developping this flake on darwin
{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    with pkgs;
    lib.mkIf stdenv.hostPlatform.isDarwin {
      packages = {
        linux-builder = darwin.linux-builder.override {
          modules = [
            {
              # force Apple's vGIC
              virtualisation.qemu.options = [
                "-machine"
                "virt,gic-version=host"
              ];
            }
          ];
        };
      };
    };

  # modules to expose for nix darwin config
  flake.darwinModules = inputs.import-tree (self + "/darwin");
}
