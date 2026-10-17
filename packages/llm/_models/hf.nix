# download a model from HF
{
  stdenvNoCC,
  python3Packages,
  owner,
  name,
  rev,
  hash,
  filename ? null,
  ...
}:
let
  hf = python3Packages.huggingface-hub;
in
stdenvNoCC.mkDerivation {
  pname = "${name}";
  version = "${rev}";

  nativeBuildInputs = [ hf ];

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;

  dontUnpack = true;

  buildPhase =
    "export HF_HOME=$TMPDIR/hf \n"
    + (
      if filename != null then
        ''
          ${hf}/bin/hf download \
            "${owner}/${name}" \
            "${filename}" \
            --revision "${rev}" \
            --local-dir model
        ''
      else
        ''
          ${hf}/bin/hf snapshot-download \
            "${owner}/${name}" \
            --revision "${rev}" \
            --local-dir model
        ''
    );

  installPhase = ''
    mkdir -p "$out"
    cp -r model/. "$out/"
    cd $out
    ln -s "$(find -iname "*.gguf" | head -1)" ./default.gguf
  '';

  preferLocalBuild = true;
  allowSubstitutes = true;
}
