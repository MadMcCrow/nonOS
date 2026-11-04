{
  inputs = import ./inputs;

  # this is done to avoid spamming until things are stabilized
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  # import flake part modules
  imports = [
    ../dev # shells and development tools
    # (sources can be in packages or src depending on who develops it)
    # ./docs -> need to implement a man/doc output
    # ./hosts -> TODO
    ../image
    ../iso
    ../lib
    ../modules
    ../packages
    ../src
  ];
};
