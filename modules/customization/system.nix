# system.nix
# replace nixOS by nonOS in the various system files
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
  # no options : we just use the general option
  # options = mkOptions { };

  config = mkIfEnable {
    environment = {
      # we don't change the ID because it's used by programs
      # to identify how they should behave
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
      stateVersion = lib.mkDefault "26.05";
      nixos.label = "${name}";
      nixos.variantName = "${name}";
    };
  };
}
