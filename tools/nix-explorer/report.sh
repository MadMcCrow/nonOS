#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  nix-closure-report [OPTIONS] FLAKE_INSTALLABLE

Options:
  -n N       Number of largest paths to report (default: 20)
  --no-build Resolve the installable without building it
  -h         Show this help

Example:
  nix-closure-report -n 10 \
    '.#nixosConfigurations.appliance.config.system.build.toplevel'
EOF
}

number=20
no_build=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      number=$2
      shift 2
      ;;
    --no-build)
      no_build=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 1 ] || { usage >&2; exit 2; }

case "$number" in
  ''|*[!0-9]*|0)
    echo "Error: -n must be a positive integer" >&2
    exit 2
    ;;
esac

installable=$1

if [ "$no_build" -eq 0 ]; then
  echo "Building $installable ..." >&2
  root=$(nix build --no-link --print-out-paths "$installable") || exit 1
else
  root=$(nix eval --raw "$installable") || exit 1
fi

# Handle installables that print multiple output paths by selecting the first.
root=$(printf '%s\n' "$root" | sed -n '1p')

[ -n "$root" ] || {
  echo "Error: no root store path found" >&2
  exit 1
}

echo "Reading closure metadata ..." >&2

# NAR sizes are available from nix path-info --json.
# Extract each path and its narSize without needing jq.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

nix path-info --recursive --json "$root" > "$tmp/info.json"

# Nix JSON objects have one path per entry, with narSize inside each entry.
# This parser relies on the usual nix path-info JSON formatting.
# Use nix-store --query --requisites for portable path enumeration.
nix-store --query --requisites "$root" > "$tmp/paths"

: > "$tmp/sizes"

while IFS= read -r path; do
  # du gives a consistent size estimate in KiB, using the store path on disk.
  size=$(du -sk "$path" | awk '{print $1}')
  printf '%s\t%s\n' "$size" "$path" >> "$tmp/sizes"
done < "$tmp/paths"

sort -nr "$tmp/sizes" | head -n "$number" > "$tmp/top"

count=$(wc -l < "$tmp/paths" | tr -d ' ')
total=$(awk '{sum += $1} END {print sum+0}' "$tmp/sizes")

human() {
  awk -v kib="$1" 'BEGIN {
    n = kib
    split("KiB MiB GiB TiB", units, " ")
    i = 1
    while (n >= 1024 && i < 4) {
      n /= 1024
      i++
    }
    printf "%.1f %s", n, units[i]
  }'
}

echo
echo "NixOS closure report"
echo "============================================================"
echo "Root:          $root"
echo "Paths:         $count"
echo "Total disk use: $(human "$total")"
echo "Showing:       $(wc -l < "$tmp/top" | tr -d ' ') largest paths"
echo
echo "Sizes are on-disk estimates; shared filesystem blocks may affect totals."

rank=0

while IFS="$(printf '\t')" read -r size path; do
  rank=$((rank + 1))
  name=${path##*/}

  printf '\n%2s. %10s  %s\n' "$rank" "$(human "$size")" "$name"
  printf '    Path: %s\n' "$path"
  printf '    Why it is needed:\n'

  if nix why-depends "$root" "$path" > "$tmp/reason" 2> "$tmp/error"; then
    sed 's/^/      /' "$tmp/reason"
  else
    echo "      Could not determine dependency chain:"
    sed 's/^/      /' "$tmp/error"
  fi
done < "$tmp/top"

echo
echo "Note: dependency chains show store references, not necessarily"
echo "the NixOS option responsible for introducing each dependency."
