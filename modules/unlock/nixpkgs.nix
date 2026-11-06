# define the options for pinning the nixpkgs version
{
  mkModule,
  mkOptions,
  meta,
  inputs,
  ...
}:
{
  lib,
  config,
  ...
}:
with (mkModule config);
with self.lib.options;
{
options = mkOptions {
  import = lib.mkOption {
    description = "how to import the nixpkgs sources (set by implementation)";
    type = lib.type.str;
    internal = true;
  };

  source = lib.mkOption {
   description = "How to fetch the nixpkgs sources";
    type = with lib.types; either
     # follow official channels, hosted on Amazon servers
      (submodule {
        options.channel = mkStrOption "branch to use" "nixos-unstable";
        }
      )
      # download from github servers
      (submodule {
        options.url = mkStrOption "nixpkgs git repository url" "https://github.com/nixOS/nixpkgs.git";
        options.branch = mkStrOption "branch to use" "nixos-unstable";
      });
      # default to channels : faster
      default = {
        channel = "nixos-unstable";
     };
};
}
