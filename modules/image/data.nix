# data.nix
# Autodetect data partitions (home, ...) by GPT partition label.
# Each entry becomes a fileSystems entry that:
#   - never blocks boot (nofail)
#   - gives up on a missing device quickly
#   - is started again when the partition shows up (udev hotplug)
{
  modConfig,
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
with (modConfig config);
let
  opts = self.lib.options;

  # systemd unit name of the mount, e.g. "/home" -> "home.mount"
  mountUnit = mountPoint: "${utils.escapeSystemdPath mountPoint}.mount";
in
{
  options = (with self.)mkOptions {
    partitions = lib.mkOption {
      description = ''
        partitions to auto-mount, keyed by GPT partition label.
        The label is matched against /dev/disk/by-partlabel/<name>.
      '';
      default = {
        "${meta.name}-home" = {
          mountPoint = "/home";
          fsType = "ext4";
        };
      };
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
            type = lib.mkOption {
              description = "filesystem type for partition" ;
              type = with opts.types; autoOr fsType;
              default = "auto";
            };
            timeout =  lib.mkOption {
              description = "timeout delay"
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
    };
  };

  config = mkIfEnable {
    # make sure the kernel and tools support each filesystem used
    boot.supportedFilesystems = with lib; with builtins;
   let
    types =  map (x: x.type) (attrValues (filterAttrs (_: v: v != "auto") cfg.partitions));
  in lib.genAttrs types (_: true );

    fileSystems = lib.mapAttrs' (
      label: p:
      lib.nameValuePair p.mountPoint {
        device = "/dev/disk/by-partlabel/${label}";
        fsType = p.type;
        options = [
          "nofail" # do not fail boot if missing
          "x-systemd.device-timeout=${p.timeout}" # do not wait long for it
        ]
        ++ p.options;
      }
    ) partitions;

    # when the partition appears (boot or later), ask systemd to start its mount.
    # no udev settle : we react to the event instead of waiting for it.
    services.udev.extraRules = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        label: p:
        ''SUBSYSTEM=="block", ENV{ID_PART_ENTRY_NAME}=="${label}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${mountUnit p.mountPoint}"''
      ) partitions
    );
  };
}
