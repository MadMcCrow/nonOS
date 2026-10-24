#!/usr/bin sh
#
# This script is called by a service and can be called directly by the user
#
#   NPINS_SYNC_DIR         npins directory (required)
#   NPINS_SYNC_CHANNEL     nixpkgs channel, e.g. nixos-unstable
#   NPINS_SYNC_GIT_URL     nixpkgs git url
#   NPINS_SYNC_GIT_BRANCH  nixpkgs git branch (needed with GIT_URL)
#   NPINS_SYNC_FORCE       clear and reinit if update fails (default: false)

case "$CLEAN_ON_FAILURE" in
  true|false) ;;
  *)
    echo "Error: CLEAN_ON_FAILURE must be 'true' or 'false'." >&2
    exit 2
    ;;
esac

if [ ! -d "$NPINS_DIR" ]; then
  echo "Error: NPINS_DIR is not an existing directory: $NPINS_DIR" >&2
  exit 1
fi

init_npins() {
  echo "Initializing npins in $NPINS_DIR..."

  npins ${lib.escapeShellArgs cfg.options} init \
    --bare --directory "$NPINS_DIR" || return $?

  npins ${lib.escapeShellArgs cfg.options} add \
    --directory "$NPINS_DIR" \
    --name nixpkgs \
    ${lib.escapeShellArgs (
      if cfg.nixpkgs ? channel then
        [ "channel" cfg.nixpkgs.channel ]
      else
        [ "git" cfg.nixpkgs.url "--branch" cfg.nixpkgs.branch ]
    )} || return $?

  echo "npins initialization succeeded."
}

# Check whether the directory contains any entries, including hidden files.
is_empty=true
for entry in "$NPINS_DIR"/* "$NPINS_DIR"/.[!.]* "$NPINS_DIR"/..?*; do
  if [ -e "$entry" ] || [ -L "$entry" ]; then
    is_empty=false
    break
  fi
done

if [ "$is_empty" = true ]; then
  init_npins
  exit $?
fi

if npins ${lib.escapeShellArgs cfg.options} update --directory "$NPINS_DIR"; then
  echo "npins update succeeded."
else
  update_status=$?
  echo "npins update failed (exit status $update_status)." >&2

  if [ "$CLEAN_ON_FAILURE" = true ]; then
    echo "Reinitializing $NPINS_DIR..." >&2

    for entry in "$NPINS_DIR"/* "$NPINS_DIR"/.[!.]* "$NPINS_DIR"/..?*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      rm -rf "$entry" || exit 1
    done

    init_npins || exit $?
  else
    exit "$update_status"
  fi
fi
