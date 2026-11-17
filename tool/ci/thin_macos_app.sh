#!/usr/bin/env bash
# Make a macOS .app contain one architecture only.
#
# Usage: bash tool/ci/thin_macos_app.sh <arch> <app-path>
#
# <arch> is x86_64 or arm64. Flutter release builds are universal, and the
# architectures cannot be narrowed for x86_64 through a Flutter feature flag
# (the only flag is arm64-only), so every Mach-O is inspected here:
#
#   - every file already carries only <arch>: nothing is changed, the Xcode
#     signature stays as it is;
#   - some file carries another slice: each Mach-O is rewritten with lipo
#     -thin and the bundle is signed again ad hoc, because rewriting a Mach-O
#     invalidates the signature Xcode wrote.
#
# After the run every Mach-O in the bundle carries exactly <arch>.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "::error::usage: thin_macos_app.sh <x86_64|arm64> <app-path>"
  exit 2
fi

arch="$1"
app="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$arch" in
  x86_64 | arm64) ;;
  *)
    echo "::error::Unknown architecture '$arch', expected x86_64 or arm64"
    exit 2
    ;;
esac

if [ ! -d "$app" ]; then
  echo "::error::App bundle is missing: $app"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
list="$work/macho.txt"

# macOS ships bash 3.2, so no mapfile: record the Mach-O files in a list file.
find "$app" -type f -print0 | while IFS= read -r -d '' file; do
  if file -b "$file" | grep -q 'Mach-O'; then
    printf '%s\n' "$file"
  fi
done > "$list"

if [ ! -s "$list" ]; then
  echo "::error::$app holds no Mach-O file"
  exit 1
fi

universal=0
failed=0
while IFS= read -r binary; do
  archs="$(lipo -archs "$binary" 2>/dev/null || true)"
  if [ -z "$archs" ]; then
    # Not a lipo image, for example a static archive. It is not code to sign.
    continue
  fi
  if [ "$archs" = "$arch" ]; then
    continue
  fi
  case " $archs " in
    *" $arch "*)
      # Still universal: thin it below.
      universal=1
      ;;
    *)
      echo "::error::${binary#"$app"/} is '$archs' and holds no $arch slice"
      failed=1
      ;;
  esac
done < "$list"
if [ "$failed" -ne 0 ]; then
  exit 1
fi

if [ "$universal" -eq 1 ]; then
  echo "Thinning $app to $arch"
  while IFS= read -r binary; do
    archs="$(lipo -archs "$binary" 2>/dev/null || true)"
    if [ -z "$archs" ] || [ "$archs" = "$arch" ]; then
      continue
    fi
    echo "  lipo -thin $arch ${binary#"$app"/} (was '$archs')"
    lipo -thin "$arch" "$binary" -output "$binary.thin"
    mv "$binary.thin" "$binary"
  done < "$list"

  # lipo rewrote signed code, so the signature must be made again. --deep
  # re-signs the nested frameworks first, then the app itself.
  if ! codesign --force --deep --sign - \
    --entitlements "$root/macos/Runner/Release.entitlements" "$app"; then
    echo "::error::Ad-hoc re-signing failed for $app"
    exit 1
  fi
fi

# Final check: every Mach-O carries exactly the target architecture.
failed=0
checked=0
while IFS= read -r binary; do
  archs="$(lipo -archs "$binary" 2>/dev/null || true)"
  if [ -z "$archs" ]; then
    continue
  fi
  checked=$((checked + 1))
  if [ "$archs" = "$arch" ]; then
    echo "PASS ${binary#"$app"/} is $arch"
  else
    echo "::error::${binary#"$app"/} is '$archs', expected only $arch"
    failed=1
  fi
done < "$list"

if [ "$checked" -eq 0 ]; then
  echo "::error::$app holds no lipo image to verify"
  exit 1
fi
if [ "$failed" -ne 0 ]; then
  exit 1
fi
if [ "$universal" -eq 0 ]; then
  echo "No multi-architecture file found. The Xcode signature is unchanged."
fi
echo "Checked $checked Mach-O files; all carry only $arch"
