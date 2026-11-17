#!/usr/bin/env bash
# Print the official Flutter stable version and framework commit.
#
# Usage: bash tool/ci/resolve_flutter.sh [version]
#
# Without an argument the latest stable from the Linux release manifest is used.
# With an argument that version is kept and only its commit is resolved. The
# output is two shell assignments, so it can be appended to $GITHUB_OUTPUT:
#
#   version=3.50.0
#   commit=ab2912035e160d9cad6306df307576da6128ebdb
#
# The manifest lists the framework commit for every release, so the default path
# needs no git access. An explicit version needs one git ls-remote at most.
set -euo pipefail

manifest="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
repository="https://github.com/flutter/flutter.git"

requested="${1:-}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 20 --retry 3 "$1"
  else
    wget -qO- --timeout=20 --tries=3 "$1"
  fi
}

# The manifest is pretty printed. Flatten it so one release stays on one line.
fetch "$manifest" > "$work/raw.json" || {
  echo "::error::Cannot download $manifest" >&2
  exit 1
}
tr -d '\n\r' < "$work/raw.json" > "$work/flat.json"

# One "<hash> <version>" line per stable release.
grep -o '"hash": *"[0-9a-f]*", *"channel": *"stable", *"version": *"[^"]*"' "$work/flat.json" \
  | sed -n 's/"hash": *"\([0-9a-f]*\)", *"channel": *"stable", *"version": *"\([^"]*\)"/\1 \2/p' \
  > "$work/stable.txt"
if [ ! -s "$work/stable.txt" ]; then
  echo "::error::No stable release in $manifest" >&2
  exit 1
fi

if [ -n "$requested" ]; then
  version="$requested"
  commit="$(sed -n "s/^\([0-9a-f]\{40\}\) $version\$/\1/p" "$work/stable.txt" | head -n 1)"
  if [ -z "$commit" ]; then
    # A version outside the manifest may still be a tag of the repository.
    commit="$(git ls-remote --tags --refs "$repository" "refs/tags/$version" 2>/dev/null \
      | sed -n '1s/[[:space:]].*//p')"
  fi
  if [ -z "$commit" ]; then
    echo "::error::Flutter $version is not a published stable release or a tag of $repository" >&2
    exit 1
  fi
else
  # current_release names the commit of the newest stable release. It sits
  # before the release list, so cut the text at "releases" before reading it.
  commit="$(cut -d '[' -f 1 "$work/flat.json" \
    | sed -n 's/.*"current_release"[^}]*"stable": *"\([0-9a-f]*\)".*/\1/p' | head -n 1)"
  if [ -z "$commit" ]; then
    echo "::error::$manifest holds no current stable release" >&2
    exit 1
  fi
  version="$(sed -n "s/^$commit \(.*\)\$/\1/p" "$work/stable.txt" | head -n 1)"
  if [ -z "$version" ]; then
    echo "::error::The manifest names stable commit $commit, but no stable line matches it" >&2
    exit 1
  fi
fi

printf 'version=%s\n' "$version"
printf 'commit=%s\n' "$commit"
