let
  root = ../.;
  lockFile = builtins.fromJSON (builtins.readFile "${root}/flake.lock");
  flake-compat-node = lockFile.nodes.${lockFile.nodes.root.inputs.flake-compat};
  flake-compat = builtins.fetchTarball {
    inherit (flake-compat-node.locked) url;
    sha256 = flake-compat-node.locked.narHash;
  };
in
import flake-compat {
    src = root;
  };
