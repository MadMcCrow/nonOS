# customization.nix
# replace nixOS by nonOS in the various config files
{
  modConfig,
  mkOptions,
  meta,
  ...
}:
{
  lib,
  config,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    # rename the OS
    customise = lib.mkEnableOption "customise nixOS to ${nonOS.name}" // {
      default = true;
    };
  };
  config = mkIfEnable {
    environment = {
      etc."os-release".text = with meta; ''
        NAME="${name}"
        PRETTY_NAME="${name}"
        VERSION_ID="${version}"
        VERSION="${version}-${status}"
        ID=nixos
        BUILD_ID="rolling"
        ANSI_COLOR="1;32"
        HOME_URL="${flake_url}"
        SUPPORT_URL="${flake_url}"
        BUG_REPORT_URL="${flake_url}/issues"
      '';
    };

    system = with meta; {
      # let the user specify the state version themselves
      # but forgetting defining it shouldn't matter
      stateVersion = "26.05";
      # We customise the
      nixos.label = "${name}";
      nixos.variantName = "${name}";
    };
  };
}
