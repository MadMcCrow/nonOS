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
    in
    {
      # built dev shell with everything
      devShells = {
        # default is for common dev
        default = mkShellNoCC {
          packages = [
            deadnix
            nixfmt-tree
            npins
            just
            shellcheck
            deadnix
            statix
            nixfmt-tree
            npins
            just
            git
            fzf
          ];
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
