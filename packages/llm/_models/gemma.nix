# yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF
{ callPackage, ... }:
callPackage ./hf.nix {
  owner = "yuxinlu1";
  name = "gemma-4-12B-coder-fable5-composer2.5-v1-GGUF";
  filename = "gemma4-coding-Q3_K_M.gguf";
  rev = "1380be1796e559fca96b4107599285cab3ddbb92";
  hash = "";
}
