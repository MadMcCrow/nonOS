#!/usr/bin/env just --justfile
#
# .justfile :
#       development justfile
#
mod packages

set quiet # do not echo commands

# recall immediately the same file with same binary
rejust := quote(just_executable()) + " --justfile " + quote(justfile())

# default command is interactive
[default]
_ :
    {{rejust}} --choose

[parallel]
update : _update_template _update_packages

_update_template :
    just ostool template update

_update_packages :
    just packages update

options :
    nix eval .#lib.options --json | jq
