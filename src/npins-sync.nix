# npins sync command for updating the system with npins
# static Go binary. npins is called by absolute store path.
{
  lib,
  buildGoModule,
  npins,
  go,
  ...
}:
buildGoModule {
  pname = "npins-sync";
  version = "0.1";
  src = ./npins-sync;

  # no external Go dependencies
  vendorHash = null;
  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.npinsBin=${lib.getExe npins}"
  ];

  meta = {
    mainProgram = "npins-sync";
    platforms = lib.intersectLists go.meta.platforms npins.meta.platforms;
  };
}
