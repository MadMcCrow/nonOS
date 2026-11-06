# Helper functions for commonly used package patterns
{ lib, stdenvNoCC, shellcheck, makeWrapper, bash, ... }:
{

  #  Builds a package from a shell script.
  #
  # Optional arguments:
  #   - script: Path to an existing shell script.
  #   - text: Inline shell script contents.
  #   - bin: Output executable name (defaults to the script filename).
  #   - shell: Shell package override (defaults to shebang detection).
  #   - env: Attribute set of environment variables to inject.
  #
  mkShellScriptPackage =
    {
      script ? null,
      text ? null,
      bin ? null,
      shell ? null,
      env ? {},
      ...
    } @args:

    let
      scriptName =
        if script != null then builtins.baseNameOf script
        else "script.sh";

      scriptFile =
        if text != null then builtins.toFile scriptName text
        else script;

      # Extract the interpreter from the shebang.
      shebang =
        if text != null then
          builtins.head (
            lib.splitString "\n" (
              lib.head (lib.splitString "\n" text)
            )
          )
        else if script != null then
          builtins.head (
            lib.splitString "\n" (
              builtins.readFile script
            )
          )
        else
          "";

      # Handle both:
      #   #!/bin/bash
      #   #!/usr/bin/env bash
      detectedShell =
        let
          parts = lib.filter (x: x != "") (
            lib.splitString " " (
              lib.removePrefix "#!" shebang
            )
          );

          interpreter =
            if lib.length parts == 0 then "bash"
            else builtins.baseNameOf (builtins.head parts);

          command =
            if interpreter == "env" && lib.length parts > 1
            then builtins.elemAt parts 1
            else interpreter;
        in
          command;

      # Explicit shell takes precedence over detection.
      selectedShell =
        if shell != null then shell
        else if detectedShell == "zsh" then pkgs.zsh
        else if detectedShell == "dash" then pkgs.dash
        else bash;

      shellName =
        if detectedShell == "sh" then "sh"
        else if shell != null then
          (shell.pname or "bash")
        else detectedShell;

      shellCheckDialect =
        if builtins.elem shellName [ "bash" "sh" "dash" "zsh" ]
        then shellName
        else "bash";

      outBin =
        if bin != null then bin
        else lib.removeSuffix ".sh" scriptName;

      defaultArgs = builtins.removeAttrs args [
        "script"
        "text"
        "bin"
        "shell"
        "env"
      ];

      envArgs = lib.mapAttrsToList
        (name: value:
          "--set ${name} ${lib.escapeShellArg (toString value)}"
        )
        env;

    in

    assert script != null || text != null;
    assert script == null || text == null;

    stdenvNoCC.mkDerivation (defaultArgs // {
      pname = args.pname or outBin;

      nativeBuildInputs =
        (args.nativeBuildInputs or [])
        ++ [ shellcheck makeWrapper ];

      patchPhase = ''
        ${if script != null then "patchShebangs ${scriptFile}" else ""}
        ${args.patchPhase or ""}
      '';

      checkPhase = ''
        shellcheck -s ${shellCheckDialect} ${scriptFile}
      '';

      installPhase = ''
        ${args.installPhase or ""}

        mkdir -p $out/share $out/bin

        install -Dm644 ${scriptFile} \
          $out/share/${scriptName}

        makeWrapper ${selectedShell}/bin/${shellName} \
          $out/bin/${outBin} \
          --add-flags $out/share/${scriptName} \
          ${lib.concatStringsSep " " envArgs}
      '';
    });
}
