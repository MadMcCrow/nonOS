# unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF
{ callPackage, ... }:
callPackage ./hf.nix {
  owner = "unsloth";
  name = "Devstral-Small-2-24B-Instruct-2512-GGUF";
  filename = "Devstral-Small-2-24B-Instruct-2512-UD-Q4_K_XL.gguf";
  rev = "6e458b8add42681bfd023de5eab93637694aaf82";
  hash = "";
}
