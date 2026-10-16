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
let
  # smaller firmware for amdgpu (do not include all of firmwares)
  AMDFirmware = pkgs.runCommand "amd-firmware" {} ''
    mkdir -p $out/lib/firmware
    cp -r ${pkgs.linux-firmware}/lib/firmware/amdgpu $out/lib/firmware/
  '';
in
{
  options = mkOptions {
    amd = {
      enable = lib.mkEnableOption "AMD Specific optimisations";
      rocm = lib.mkEnableOption "AMD ROCM GPGPU software";
    };
    openCL = lib.mkEnableOption "OpenCL support";
    support32bit = lib.mkEnableOption "32bit options";
  };

  config = mkIfEnable {
    # make sure amdgpu is supported from boot
    boot.initrd.kernelModules = lib.optional cfg.amd.enable "amdgpu";

    hardware = {

      enableAllFirmware = lib.mkDefault false;
      enableRedistributableFirmware = lib.mkDefault false;
      # https://wiki.nixos.org/wiki/AMD_GPU#Error:_amdgpu:_Failed_to_get_gpu_info_firmware
      firmware = lib.optional cfg.amd.enable AMDFirmware;
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

    environment.systemPackages = lib.lists.flatten [
      (lib.optional (cfg.amd.enable && cfg.amd.rocm) pkgs.lact)
     (lib.optional cfg.openCL    pkgs.clinfo)
      ];

    environment.variables = lib.mkIf cfg.amd.enable { AMD_VULKAN_ICD = "RADV"; # force use of radv
    };

    systemd = lib.mkIf (cfg.amd.enable && cfg.amd.rocm) {
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
    # enable rocm version of packages
    nixpkgs.config.rocmSupport = cfg.amd.enable && cfg.amd.rocm;
  };
}
