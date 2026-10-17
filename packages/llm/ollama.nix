# llama-cpp
# a wrapper around llama-cpp for simpler deployment
{
  pkgs,
  name ? "llm-ollama",
  model ? "yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF",
  ...
}:
let
  config = import ./_config.nix;
  pkg = if config.useROCM then pkgs.ollama-rocm else pkgs.ollama;
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [ pkg ];
  text = ''
    export HF_HOME="$HOME/.cache/huggingface"
    export TRANSFORMERS_CACHE="$HF_HOME/transformers"
    export HF_DATASETS_CACHE="$HF_HOME/datasets"
    export OLLAMA_HOST="0.0.0.0:${toString config.port}"
    export OLLAMA_NOHISTORY=1
    # export OLLAMA_CONTEXT_LENGTH=${toString (config.cacheGB * 1024)}
    ${pkgs.lib.getExe pkg} start
    ${pkgs.lib.getExe pkg} run hf.co/${model}
  '';
}
