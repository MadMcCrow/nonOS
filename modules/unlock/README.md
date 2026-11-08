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

 - `system.nix` generates that entry point. It loads nonOS with flake-compat (the `default.nix` at the root) and your `configuration`.
 - `nixos-rebuild` finds it through the `nixos-system` entry in `NIX_PATH`.
 - `unlock.nix` holds the shared options and the config directory (`/etc/nonOS/unlock`).
 - `update.nix` defines the backend option and a service that updates the pin.
 - `rebuild.nix` configures `system.autoUpgrade`. The update service runs before it.
 - `implementations/` has one file per backend : `nurl` (channel tarball), `npins`, `tack` (stub).
 - `assert.nix` forbids using unlock with image.

# First boot

The pin does not exist until the update service ran once :

    sudo systemctl start nonOS-unlock.service
    sudo nixos-rebuild switch

`dates`, `operation` and `allowReboot` are the usual `system.autoUpgrade` options.
