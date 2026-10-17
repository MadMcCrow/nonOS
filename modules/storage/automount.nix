# automount.nix
# Autodetect data partitions (home, ...) by GPT partition label.
# Each entry becomes a fileSystems entry that:
#   - never blocks boot
#   - is started again with udev hotplug
{
  mkModule,
  mkOptions,
  meta,
  self,
  ...
}:
{
  lib,
  config,
  utils,
  ...
}:
with (mkModule config);
let
  opts = self.lib.options;
  # systemd unit for mount point
  mountUnit = mountPoint: "${utils.escapeSystemdPath mountPoint}.mount";
in
{
  options = mkOptions (
    lib.mkOption {
      description = ''
        partitions to auto-mount, keyed by GPT partition label.
        The label is matched against /dev/disk/by-partlabel/<name>.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          "nonOS-home" = { mountPoint = "/home"; fsType = "btrfs"; };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mountPoint = lib.mkOption {
              description = "where to mount the partition";
              type = lib.types.path;
              example = "/home";
            };
            fsType = lib.mkOption {
              description = "filesystem type for partition";
              type = with opts.types; autoOr fsType;
              default = "auto";
            };
            timeout = lib.mkOption {
              description = "timeout delay";
              default = "100ms";
              type = opts.types.duration;
            };
            options = lib.mkOption {
              description = "extra mount options";
              type = with lib.types; listOf str;
              default = [ ];
            };
          };
        }
      );
    }
  );

  config = mkIfEnable {
    # make sure the kernel and tools support each filesystem used
    boot.supportedFilesystems =
      with lib;
      with builtins;
      let
        types = map (x: x.fsType) (attrValues (filterAttrs (_: v: v != "auto") cfg));
      in
      lib.genAttrs types (_: true);

    fileSystems = lib.mapAttrs' (
      label: p:
      lib.nameValuePair p.mountPoint {
        device = "/dev/disk/by-partlabel/${label}";
        inherit (p) fsType;
        options = [
          "nofail" # do not fail boot if missing
          "x-systemd.device-timeout=${p.timeout}" # do not wait long for it
        ]
        ++ p.options;
      }
    ) cfg;

    # when the partition appears (boot or later), ask systemd to start its mount.
    # no udev settle : we react to the event instead of waiting for it.
    services.udev.extraRules = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        label: p:
        ''SUBSYSTEM=="block", ENV{ID_PART_ENTRY_NAME}=="${label}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${mountUnit p.mountPoint}"''
      ) cfg
    );
  };
}
