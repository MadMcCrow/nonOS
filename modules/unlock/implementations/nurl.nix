# nurl.nix
# use nurl to generate the nixpkgs pin
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
  # generate the argument to use for nurl
  url =
    if mod.nixpkgs ? channel then
      "https://channels.nixos.org/${mod.channel}/nixexprs.tar.zst"
    else
      "${mod.url} ${mod.branch}";

  # where we will store the nix fetcher expression
  nixpkgsSource = cfg.source;

  # we default to a version of the nixpkgs
  updateNixpkgs = pkgs.writeShellScriptBin mod.update.program.name ''
    # remove existing pin :
    rm -Rf ${nixpkgsSource}
    # redirect nurl output to a file, ready to be imported by nix
    ${pkgs.nurl} ${url} > ${nixpkgsSource};
  '';
in
{
  # interface
  options = mkOptions {
    enable = lib.mkEnableOption "nurl implementation for ${moduleName}";
    source = mkPathOption "nurl output file" "${mod.configDir}/source.nix";
    # TODO :
  };

  # WIP
  config = mkIfEnableAnd cfg.enable {
    # set our own update package
    ${meta.name}.${moduleName} = {
      update.program.package = updateNixpkgs;
      system.nixpkgs = "import ${nixpkgsSource}";
    };

    # make sure the file exists and contains the installed source
    # it will be replaced by `updateNixpkgs`
    systemd.tmpfiles.rules = [
      "f ${nixpkgsSource} 0644 root root - <nixpkgs>"
    ];
  };
}
