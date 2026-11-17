#!/usr/bin/env bash
# Print the app version from pubspec.yaml without the build number.
#
# Usage: bash tool/ci/app_version.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
version="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' "$root/pubspec.yaml" | head -n 1)"
if [ -z "$version" ]; then
  echo "::error::pubspec.yaml has no version" >&2
  exit 1
fi
printf '%s\n' "$version"
