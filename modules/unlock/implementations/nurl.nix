# nurl.nix
# we use `nurl` to generate a file that looks like
#
{
  mkModule,
  mkOptions,
  meta,
  moduleName,
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
let
  # sources to pin
  pinned = ["nixpkgs" meta.name];


  # channels don't have fixed urls so we resolve them with curl
  channelUrl = let
    base = "https://channels.nixos.org/${mod.nixpkgs.channel}/nixexprs.tar.zst";
  in "$(${pkgs.curl} -Ls -o /dev/null -w '%{url_effective}\n' ${base})";

  # generate the argument to use for nurl
  url =
    if mod.nixpkgs ? channel then channelUrl
    else
      "${mod.url} ${mod.branch}";

  # we default to a version of the nixpkgs
  updateNixpkgs = pkgs.writeShellScriptBin mod.update.program.name ( map (x: ''
    NURL_SOURCE_FILE="${cfg.sources.${x}}"
    # remove existing pin if any
    rm -Rf $NURL_SOURCE_FILE && true
    # redirect nurl output to a file, ready to be imported by nix
    ${pkgs.nurl} ${url} > $NURL_SOURCE_FILE
  '' pinned);
in
{
  # interface
  options = mkOptions {
    enable = lib.mkEnableOption "nurl implementation for ${moduleName}";
    # each pinned input gets its own output file, imported with "import ${file}; into the nix code".
    sources = lib.genAttrs pinned (x : mkPathOption "nurl output file for ${x}" "${mod.configDir}/${x}.nix");
  };

  # WIP
  config = mkIfEnableAnd cfg.enable {
    # set our own update package
    ${meta.name}.${moduleName} = {
      update.program.package = updateNixpkgs;
      system.nixpkgs      = "import ${cfg.sources.nixpkgs}";
      system.${meta.name} = "import ${cfg.sources.${meta.name}}";
    };

    # make sure the file exists and contains the installed source
    # it will be replaced by `updateNixpkgs`
    systemd.tmpfiles.rules = [
      "f ${nixpkgsSource} 0644 root root - <nixpkgs>"
    ];
  };
}
