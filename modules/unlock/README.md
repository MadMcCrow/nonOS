# Unlock (from flake input)

this module focus on allowing to have an update process for a machine that allows setting the "pinned" revision of nixpkgs at the update time, keeping the nixOS configuration untouched.

other name have been considered ( rolling, refresh, rebase) but they do not really convey the goal of "unpinning/unlocking" nixpkgs, just like channels used to do.

tools that inspired this :
 - npins
 - tack
 - impurity
 - comin

 # Implementation
 
 The entry point to build the configuration is the new `system.nix` from 26.05. In it, we source the nixpkgs version to use to build nonOS.

 to achieve this result, there's multiple tools we can use, the simplest being `nurl`. the simplest approach is to overwrite a symlink file and replace it at fixed times with a new
