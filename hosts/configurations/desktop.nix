# my desktop PC
{ nonOS, pkgs, ... }: {
  # use the PC profile for desktop
  imports = nonOS.profiles.pc;
  config = {
    nonOS.storage.bcachefs = {
      enable = true;
      # TODO : autodect and mount pool
    };
    nonOS.unlock = {
      enable = true;
      # TODO : mark this config file as the config to follow.
    };
  };
}
