#!/usr/bin/env bash
# Stage one target's packages with licenses, build facts and checksums.
#
# Usage: QFLI_SIGNING="<signing state>" bash tool/ci/stage_artifact.sh <target> <file>...
#
# Output: build/ci-artifacts/<target>/ in the app checkout.
# The target name is both the artifact name and the output directory name, so it
# carries the app version, the platform and the architecture.
#
# Optional: QFLI_BUILD_INFO_EXTRA names a file whose lines are appended to
# BUILD_INFO.txt, for the toolchain versions of the calling job.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "::error::usage: stage_artifact.sh <target> <file>..."
  exit 2
fi
if [ -z "${QFLI_SIGNING:-}" ]; then
  echo "::error::QFLI_SIGNING must describe the signing state of the package"
  exit 2
fi

target="$1"
shift
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$root/build/ci-artifacts/$target"

# A release package may never carry an unknown or pending plugin fact. The
# facts come from tool/ci/plugin_provenance.py, which fails the job before this
# script runs when the pinned plugin is incomplete; this guard catches a caller
# that forgets to export them.
require_fact() {
  local name="$1" value="${2:-}"
  if [ -z "$value" ] || [ "$value" = "unknown" ] || [ "$value" = "pending" ]; then
    echo "::error::$name is '${value:-empty}'; a release package needs a pinned qfli_git"
    exit 1
  fi
}
# The collector writes 0 for a complete import and 1 for an interim pin.
# Default omitted legacy callers to 0; the required facts below still gate them.
QFLI_PLUGIN_PENDING="${QFLI_PLUGIN_PENDING:-0}"
require_fact QFLI_PLUGIN_VERSION "${QFLI_PLUGIN_VERSION:-}"
require_fact QFLI_PLUGIN_COMMIT "${QFLI_PLUGIN_COMMIT:-}"
require_fact QFLI_PLUGIN_API_VERSION "${QFLI_PLUGIN_API_VERSION:-}"
require_fact QFLI_PLUGIN_NATIVE_SOURCE "${QFLI_PLUGIN_NATIVE_SOURCE:-}"
require_fact QFLI_PLUGIN_NATIVE_RELEASE "${QFLI_PLUGIN_NATIVE_RELEASE:-}"
require_fact QFLI_PLUGIN_CACERT_SHA256 "${QFLI_PLUGIN_CACERT_SHA256:-}"
if [ "$QFLI_PLUGIN_PENDING" != "0" ]; then
  echo "::error::QFLI_PLUGIN_PENDING=$QFLI_PLUGIN_PENDING; a release package needs imported native artifacts"
  exit 1
fi
if [ "${QFLI_PLUGIN_API_VERSION}" != "2" ]; then
  echo "::error::QFLI_PLUGIN_API_VERSION=${QFLI_PLUGIN_API_VERSION}; the app requires API 2"
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"

for package in "$@"; do
  if [ ! -s "$package" ]; then
    echo "::error::Package is missing or empty: $package"
    exit 1
  fi
  cp "$package" "$out/"
done
cp "$root/LICENSE" "$out/LICENSE"

sdk_root="${QFLI_FLUTTER_ROOT:-}"
flutter_commit="unknown"
if [ -n "$sdk_root" ] && [ -d "$sdk_root/.git" ]; then
  flutter_commit="$(git -C "$sdk_root" rev-parse HEAD)"
fi

{
  echo "target=$target"
  echo "app_version=$(bash "$root/tool/ci/app_version.sh")"
  echo "app_commit=${GITHUB_SHA:-$(git -C "$root" rev-parse HEAD)}"
  echo "core_commit=${QFLI_CORE_COMMIT:-unknown}"
  echo "flutter_version=${QFLI_FLUTTER_VERSION:-unknown}"
  echo "flutter_commit=$flutter_commit"
  echo "flutter_mode=${QFLI_FLUTTER_MODE:-unknown}"
  echo "build_mode=release"
  echo "plugin=qfli_git"
  echo "plugin_version=$QFLI_PLUGIN_VERSION"
  echo "plugin_commit=$QFLI_PLUGIN_COMMIT"
  echo "plugin_native_api_version=$QFLI_PLUGIN_API_VERSION"
  echo "plugin_native_source=$QFLI_PLUGIN_NATIVE_SOURCE"
  echo "plugin_native_release=$QFLI_PLUGIN_NATIVE_RELEASE"
  echo "plugin_cacert_sha256=$QFLI_PLUGIN_CACERT_SHA256"
  echo "plugin_pending=$QFLI_PLUGIN_PENDING"
  echo "runner=${RUNNER_OS:-$(uname -s)} ${RUNNER_ARCH:-$(uname -m)} ${ImageOS:-}"
  echo "signing=$QFLI_SIGNING"
  echo "device_validation=none"
  if [ -n "${GITHUB_RUN_ID:-}" ]; then
    echo "run=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  fi
  if [ -n "${QFLI_BUILD_INFO_EXTRA:-}" ] && [ -f "$QFLI_BUILD_INFO_EXTRA" ]; then
    echo "--- toolchain ---"
    tr -d '\r' < "$QFLI_BUILD_INFO_EXTRA"
  fi
} > "$out/BUILD_INFO.txt"

cd "$out"
files=()
while IFS= read -r name; do
  files+=("$name")
done < <(ls -1 | LC_ALL=C sort)

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${files[@]}" > SHA256SUMS
else
  shasum -a 256 "${files[@]}" > SHA256SUMS
fi

echo "Staged $target:"
ls -l
cat SHA256SUMS
