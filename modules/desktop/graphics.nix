# graphics.nix
# define how nonOS handles GPUs (mostly AMD)
{
  mkModule,
  mkOptions,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with (mkModule config);
{
  options = mkOptions {
    amd.enable = lib.mkEnableOption "AMD Specific optimisations";
    support32bit = lib.mkEnableOption "32bit options";
  };

  config = mkIfEnable {
    # make sure amdgpu is supported from boot
    boot.initrd.kernelModules = lib.optional cfg.amd.enable "amdgpu";

    hardware = {
      # https://wiki.nixos.org/wiki/AMD_GPU#Error:_amdgpu:_Failed_to_get_gpu_info_firmware
      firmware = lib.optional cfg.amd.enable pkgs.linux-firmware;
      # amd specific :
      amdgpu = lib.mkIf cfg.amd.enable {
        initrd.enable = true;
        opencl.enable = true;
      };
      # enable graphics :
      graphics = {
        enable = true;
        enable32Bit = cfg.support32bit;
        # can cause issue
        # extraPackages = lib.mkForce [ ];
        # extraPackages32 = lib.mkForce [ ];
      };
    };

    environment = lib.mkIf cfg.amd.enable {
      systemPackages = with pkgs; [
        lact # Linux AMDGPU Controller
        clinfo # to test opencl setup
      ];
      variables.AMD_VULKAN_ICD = "RADV"; # force use of radv
    };

    systemd = lib.mkIf cfg.amd.enable {
      # enable rocm for amd gpus
      tmpfiles.rules =
        let
          rocmEnv = pkgs.symlinkJoin {
            name = "rocm-combined";
            paths = with pkgs.rocmPackages; [
              rocblas
              hipblas
              clr
            ];
          };
        in
        [ "L+    /opt/rocm   -    -    -     -    ${rocmEnv}" ];

      # enable lact daemon
      packages = with pkgs; [ lact ];
      services.lactd.wantedBy = [ "multi-user.target" ];
    };

    # force enable rocm support if amd gpu is present
    nixpkgs.config.rocmSupport = cfg.amd.enable;
  };
}
