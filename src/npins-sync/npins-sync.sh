#!/usr/bin/env sh
#
# This script is called by a service and can be called directly by the user
#
#   NPINS_SYNC_DIR         npins directory (required)
#   NPINS_SYNC_CHANNEL     nixpkgs channel, e.g. nixos-unstable
#   NPINS_SYNC_GIT_URL     nixpkgs git url
#   NPINS_SYNC_GIT_BRANCH  nixpkgs git branch (needed with GIT_URL)
#   NPINS_SYNC_FORCE       clear and reinit if update fails (default: false)


### Parsing commandline arguments

usage() {
    # -f sets NPINS_SYNC_FORCE to true
    echo "Usage: $0 [-d NPINS_SYNC_DIR] [(-c NPINS_SYNC_CHANNEL)|(-u NPINS_SYNC_GIT_URL -b NPINS_SYNC_GIT_BRANCH)] [-f]" >&2
    exit 1
}

# get values from env
NPINS_SYNC_DIR=${NPINS_SYNC_DIR:-./}
NPINS_SYNC_CHANNEL=${NPINS_SYNC_CHANNEL:-}
NPINS_SYNC_GIT_URL=${NPINS_SYNC_GIT_URL:-}
NPINS_SYNC_GIT_BRANCH=${NPINS_SYNC_GIT_BRANCH:-}
NPINS_SYNC_FORCE=${NPINS_SYNC_FORCE:-false}
NPINS_SYNC_OPTIONS=${NPINS_SYNC_OPTIONS:-}

# command line will possibly change mode (git or channel)
mode=

while getopts "d:c:u:b:fh" opt; do
    case "$opt" in
        d)
            NPINS_SYNC_DIR=$OPTARG
            ;;
        c)
            [ "$mode" = "" ] || usage
            mode=channel
            NPINS_SYNC_CHANNEL=$OPTARG
            ;;
        u)
            [ "$mode" = "" ] || [ "$mode" = git ] || usage
            mode=git
            NPINS_SYNC_GIT_URL=$OPTARG
            ;;
        b)
            [ "$mode" = "" ] || [ "$mode" = git ] || usage
            mode=git
            NPINS_SYNC_GIT_BRANCH=$OPTARG
            ;;
        f)
            NPINS_SYNC_FORCE=true
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

shift "$((OPTIND - 1))"

# No unexpected positional arguments
[ "$#" -eq 0 ] || usage

# Validate the effective configuration
case "$mode" in
    channel)
        # CLI channel overrides environment Git settings
        NPINS_SYNC_GIT_URL=
        NPINS_SYNC_GIT_BRANCH=
        [ -n "$NPINS_SYNC_CHANNEL" ] || usage
        ;;
    git)
        # CLI Git settings override environment channel
        NPINS_SYNC_CHANNEL=
        [ -n "$NPINS_SYNC_GIT_URL" ] || usage
        [ -n "$NPINS_SYNC_GIT_BRANCH" ] || usage
        ;;
    *)
        # No mode selected on CLI; validate environment defaults
        if [ -n "$NPINS_SYNC_CHANNEL" ]; then
            [ -z "$NPINS_SYNC_GIT_URL" ] &&
                [ -z "$NPINS_SYNC_GIT_BRANCH" ] || usage
        else
            [ -n "$NPINS_SYNC_GIT_URL" ] &&
                [ -n "$NPINS_SYNC_GIT_BRANCH" ] || usage
        fi
        ;;
esac


### defaults
# Only evaluate those after parsing arguments and env-vars
NPINS_BIN="npins"
NPINS_OPTIONS="$NPINS_SYNC_OPTIONS --directory $NPINS_DIR"

# method to initialize if directory is empty
init_npins() {
  # init bare repository
  $NPINS_BIN $NPINS_OPTIONS init --bare  || return $?
  case "$mode" in
      channel)
          $NPINS_BIN $NPINS_OPTIONS add --name nixpkgs channel $NPINS_SYNC_CHANNEL || return $?
          ;;
      git)
          $NPINS_BIN $NPINS_OPTIONS add --name nixpkgs git $NPINS_SYNC_GIT_URL --branch $NPINS_SYNC_GIT_BRANCH || return $?
          ;;
  esac
}

# call update
# TODO : detect if we are in channel or branch mode
#        and update accordingly ( might need to remove and add again)
update_npins() {
    $NPINS_BIN $NPINS_OPTIONS update --full || return $?
}

# check for sources at target :
if [ ! -f "$NPINS_DIR/sources.json" ]; then
    init_npins
    init_status=$?
    echo "initialized npins source directory $NPINS_DIR with exit code $init_status"
    exit "$init_status"
fi

# try update first : handle errors later :
if update_npins; then
      echo "npins update succeeded."
    else if [ "$NPINS_SYNC_FORCE" = true ]; then
        rm "$NPINS_DIR/*" -Rf
        init_npins
        init_status=$?
        echo "reinitialized npins source directory $NPINS_DIR with exit code $init_status"
        exit "$init_status"
    else
        update_status=$?
        echo "npins update failed (exit status $update_status)." >&2
    fi
fi
