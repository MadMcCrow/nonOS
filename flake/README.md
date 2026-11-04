# nonOS Flake

the `flake.nix` file at the root of the repository is just a shim for other tools that uses flakes. You'll find the explaination below. In this directory, you'll find my attempt at replacing the flawed flakes by a system that relies on other tools from the ecosystem.

# Flake support.

Originally this project was built as a flake first approach. The more I worked with flakes the more I had strong opinions about it, and the more it felt like it was a half solution to a half problem.

## the good.

Flakes solves a real double edge problem : "how do you gain reproducibility while keeping a functionnal approach ?".
Having a clean input -> output path seems like the best idea so far. the deduplication of inputs via `follows` is also a proof that we don't sacrifice the ecosystem either. it allows to build on common bricks and allows each and every brick to make their versions compatible and move forward together.

## the bad.

flakes loose a lot of interest once you start using a lot of non-flake inputs. Having a fixed "supported" output schema is counter productive as we cannot really expand it as we want and have to wait for the norm to evolve.

## the ugly.

Call me names if you want, but I consider that if a filename ends with `.nix` it should be a nix file. unfortunately, flakes seems to be special nix code that does not support non-trivial expression, `let ... in` blocks, etc.

## What I wish flakes were.

If I was in charge of designing flakes, this is what I would do :
 - flake is pure nix code, it evaluates just like the rest. importing is totally possible.
 - inputs can be defined in multiple files.
 - outputs follows a schema defined in the same flake.
 - any file can be a flake.
  - two fields are strictly necessary : `inputs`, `outputs`.
  - other fields include : `schema` ( how outputs are defined and visualized by `nix flake show`, post update commands, etc.) ,`meta` ( description, name, etc. ) and `lock` (where the lock file is supposed to be.).
  - in the absence of fields. they could be implicit for the sake of retro-compatibility. ( `lock = ./flake.lock;` for example).

## Until then.

Until a reasonable standard emerges, I'll simply use flakes as a shim for a "better" managed system.
Fortunately, the philosophy behind nonOS is a matter of opinion, so making an opiniated decision seems the most reasonable thing to do.
