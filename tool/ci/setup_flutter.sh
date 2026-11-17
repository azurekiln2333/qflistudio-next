#!/usr/bin/env bash
# Install a Flutter SDK by git clone and verify the framework commit.
#
# Usage: bash tool/ci/setup_flutter.sh <target-directory> <version> <commit> [--ohos]
#
# Every CI runner uses git clone: the official archive is x64 only, so an arm64
# host has no other way to get a working SDK. Without --ohos the official
# repository is used; with it the HarmonyOS fork is used and the version is the
# fork tag.
set -euo pipefail

UPSTREAM_REPOSITORY="https://github.com/flutter/flutter.git"
OHOS_REPOSITORY="https://gitcode.com/openharmony-tpc/flutter_flutter.git"

mode="upstream"
arguments=()
for argument in "$@"; do
  case "$argument" in
    --ohos) mode="ohos" ;;
    *) arguments+=("$argument") ;;
  esac
done

if [ "${#arguments[@]}" -ne 3 ]; then
  echo "::error::usage: setup_flutter.sh <target-directory> <version> <commit> [--ohos]"
  exit 2
fi

target="${arguments[0]}"
version="${arguments[1]}"
commit="${arguments[2]}"

if [ "$mode" = "ohos" ]; then
  repository="$OHOS_REPOSITORY"
else
  repository="$UPSTREAM_REPOSITORY"
fi

if command -v cygpath >/dev/null 2>&1; then
  target="$(cygpath -u "$target")"
fi

installed_commit() {
  git -C "$target" rev-parse HEAD 2>/dev/null || true
}

if [ -x "$target/bin/flutter" ] && [ "$(installed_commit)" = "$commit" ]; then
  echo "Flutter SDK already present at $commit"
else
  cloned=0
  for attempt in 1 2 3; do
    rm -rf "$target"
    # A tag can be moved upstream, so the commit check below decides.
    if git clone --depth 1 --branch "$version" "$repository" "$target"; then
      cloned=1
      break
    fi
    echo "::warning::Flutter SDK clone attempt $attempt failed"
    sleep $((attempt * 15))
  done
  if [ "$cloned" -ne 1 ]; then
    echo "::error::Could not clone $repository at $version"
    exit 1
  fi
fi

actual="$(installed_commit)"
if [ "$actual" != "$commit" ]; then
  echo "::error::Flutter SDK commit is '$actual', expected $commit for $version"
  exit 1
fi

# The flutter tool derives its version from the tag. A shallow clone must keep it.
if ! git -C "$target" describe --tags --exact-match >/dev/null 2>&1; then
  git -C "$target" fetch --depth 1 origin "refs/tags/$version:refs/tags/$version"
fi

echo "Flutter SDK $version ($commit) ready in $target"
