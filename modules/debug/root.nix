# root.nix
# Module to set the boot timemout for faster debug
{modConfig, mkOptions, ...} :
{lib, config, ...} :
with (modConfig config);
{
options = mkOptions {
  # extra enable option to be off by default
  enable = lib.mkEnableOption "root boot access (WARNING: it's dangerous !)";
};
 config = mkIfEnableAnd cfg.enable {
  # unsafe
  services.getty.autologinUser = "root";
  users.allowNoPasswordLogin = true;
  users.users.root.hashedPassword = "$y$j9T$efeFSSCdXT41oO/YqlvSX.$61j5A7D9GxkpWUJREaWCAtXke9.rnrDRbH6YoLyXJH4";
  boot.initrd.systemd.emergencyAccess = "$y$j9T$efeFSSCdXT41oO/YqlvSX.$61j5A7D9GxkpWUJREaWCAtXke9.rnrDRbH6YoLyXJH4";
  systemd.enableEmergencyMode = true;
};
}
