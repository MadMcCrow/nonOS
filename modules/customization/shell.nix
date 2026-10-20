# shell.nix
# zsh is the far superior shell in my opinion
{
  mkModule,
  mkOptions,
  inputs,
  self,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (mkModule config);
with self.lib.options;
{
  # interface
  options = mkOptions {
    # TODO : move to true
    forceZsh = mkBoolOption "force use zsh as the default shell" false;
  };

  # implementation
  config = mkIfEnableAnd cfg.forceZsh {
    programs = {
      zsh.enable = true;
      bash.enable = lib.mkForce false;
    };
    users.defaultUserShell = pkgs.zsh;
  };
}
