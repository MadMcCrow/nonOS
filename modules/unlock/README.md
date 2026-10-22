# Unlock (from flake input)

this module focus on allowing to have an update process for a machine that allows setting the "pinned" revision of nixpkgs at the update time, keeping the nixOS configuration untouched.
this revolve a lot around using `nixpkgs.pkgs` or `nixpkgs.overlay` and `nixpkgs.config` options.

other name have been considered ( rolling, refresh, rebase) but they do not really convey the goal of "unpinning/unlocking" nixpkgs.

tools that inspired this :
 - npins
 - tack
 - impurity
 - comin
