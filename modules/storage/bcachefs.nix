# bcachefs.nix
# Support bcachefs filesystem
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
    # TODO : evaluate enabling by default
    enable = lib.mkEnableOption "bcachefs filesystem support";
  };
  config = mkIfEnableAnd cfg.enable {
    # make sure it's supported at boot
    boot = {
      supportedFilesystems = [ "bcachefs" ];
      # probably superfluous
      extraModulePackages = [
        config.boot.kernelPackages.bcachefs
      ];
    };
    # keyutils is required as a workaround for bug
    # https://github.com/NixOS/nixpkgs/issues/32279
    environment.systemPackages = with pkgs; [
      keyutils
      bcachefs-tools
    ];
    #TODO :
    # add https://wiki.nixos.org/wiki/Bcachefs#Remote_encrypted_disk_unlocking
    #
  };
}
