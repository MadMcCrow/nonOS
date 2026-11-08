{ nonOS, pkgs }: {
  # MAYBE : make profiles that auto-imports all the correct modules
  imports = with nonOS.nixosModules; [
    audio
    desktop
    storage
    customization
    unlock
  ];
  config = {
    nonOS.storage.bcachefs = {
      enable = true;
      # TODO : autodect and mount pool
    };

  };
}
