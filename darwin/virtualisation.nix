{ pkgs, ... }:
{
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
