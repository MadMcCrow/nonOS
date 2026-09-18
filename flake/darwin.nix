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
    lib.mkIf false { # pkgs.stdenv.hostPlatform.isDarwin
      packages = {
        linux-builder = pkgs.darwin.linux-builder.override {
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
  flake.darwinModules = {
    default =  {pkgs, ...} : {
      nix = {
        linux-builder = {
        enable = true;
        ephemeral = true;
        maxJobs = 4;
        # Force the builder to claim apple-virt and kvm support flags
        supportedFeatures = [ "kvm" "benchmark" "big-parallel" "nixos-test" "apple-virt" ];
      };
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
      };
        # Explicitly enforce apple-virt as a system feature on the host macOS sides
        system-features = [ "nixos-test" "apple-virt" "gccarch-armv8-a" ];
      };
    };
  };
}
