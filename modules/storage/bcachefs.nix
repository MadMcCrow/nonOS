# zfs.nix
# Support zfs filesystem
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
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
{
  options = mkOptions {
    enable = lib.mkEnableOption "bcachefs filesystem support";
  };
  config = lib.mkIfEnableAnd cfg.enable {
    # Required as a workaround for bug
    # https://github.com/NixOS/nixpkgs/issues/32279
    environment.systemPackages = [ pkgs.keyutils ];
    boot.supportedFilesystems = [ "bcachefs" ];

    #TODO :
    # add https://wiki.nixos.org/wiki/Bcachefs#Remote_encrypted_disk_unlocking
    #
  };
}
