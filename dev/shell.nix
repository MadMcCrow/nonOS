# devshells for flake
# flake part module for dev shells
{
  self,
  withSystem,
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    with builtins;
    with pkgs;
    let
      # local llm support :not recommended because it's heavy
      llmserver = callPackage (self + "/packages/ai/llama-cpp.nix") inputs;
      #
      srcDependencies = lib.flatten (map (x: x.nativeBuildInputs or []) (attrValues self.packages));
    in
    {
      # built dev shell with everything
      devShells = {
        # default is for common dev
        default = mkShell {
          # make sure this shell will work for use
          NIX_CONFIG = "experimental-features = nix-command flakes";

          packages = [
            npins
            just
            shellcheck
            deadnix
            statix
            nixfmt-tree
            just
            git
            fzf
          ] ++
          srcDependencies;
        };

        llm = mkShellNoCC {
          packages = [
            llmserver
          ];
          shellHook = ''
            echo "starting llm server"
            ${pkgs.lib.getExe llmserver} &
          '';
        };
      };
    };
}
