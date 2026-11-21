#!/usr/bin/env bash
# Package a Flutter Linux release bundle as a .tar.gz and a .deb.
#
# Usage: bash tool/ci/package_linux.sh <arch> <bundle-dir> <output-dir>
#
# <arch> is x64 or arm64. Output:
#   <output-dir>/qflistudio_<version>_<amd64|arm64>.deb
#   <output-dir>/qflistudio-<version>-linux-<x64|arm64>.tar.gz
#
# The .deb installs the bundle to /opt/qflistudio. Flutter resolves data/ and
# lib/ beside the real executable, so /usr/bin/qflistudio is a launcher script.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "::error::usage: package_linux.sh <x64|arm64> <bundle-dir> <output-dir>"
  exit 2
fi

arch="$1"
bundle="$(cd "$2" && pwd)"
mkdir -p "$3"
output="$(cd "$3" && pwd)"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$arch" in
  x64) deb_arch="amd64" ;;
  arm64) deb_arch="arm64" ;;
  *)
    echo "::error::Unknown architecture '$arch', expected x64 or arm64"
    exit 2
    ;;
esac

binary_name="qflistudio"
application_id="com.azurekiln.qflistudio"
package_name="qflistudio"
install_dir="/opt/$package_name"
version="$(bash "$root/tool/ci/app_version.sh")"

# The macOS icon set holds the multi-size PNGs; the 256 px one scales well.
icon_256="$root/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
icon_any="$root/assets/app_icon.png"
for candidate in "$icon_256" "$icon_any"; do
  if [ -s "$candidate" ]; then
    icon="$candidate"
    break
  fi
done
if [ -z "${icon:-}" ]; then
  echo "::error::No PNG app icon in macos/Runner/Assets.xcassets/AppIcon.appiconset or assets"
  exit 1
fi

if [ -z "$version" ]; then
  echo "::error::pubspec.yaml holds no version"
  exit 1
fi
if [ ! -x "$bundle/$binary_name" ]; then
  echo "::error::Bundle executable is missing: $bundle/$binary_name"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Portable archive: the bundle under one versioned top-level directory.
tar_name="qflistudio-$version-linux-$arch"
mkdir -p "$work/tar/$tar_name"
cp -a "$bundle/." "$work/tar/$tar_name/"
cp "$root/LICENSE" "$work/tar/$tar_name/LICENSE"
tar -C "$work/tar" -czf "$output/$tar_name.tar.gz" "$tar_name"

# Debian package tree.
deb_root="$work/deb"
mkdir -p "$deb_root/DEBIAN" "$deb_root$install_dir" "$deb_root/usr/bin" \
  "$deb_root/usr/share/applications" "$deb_root/usr/share/pixmaps" \
  "$deb_root/usr/share/doc/$package_name"
cp -a "$bundle/." "$deb_root$install_dir/"

cat > "$deb_root/usr/bin/$package_name" <<EOF
#!/bin/sh
exec $install_dir/$binary_name "\$@"
EOF

# The runner calls g_set_prgname with the application ID, so the window class
# equals the desktop file name.
cat > "$deb_root/usr/share/applications/$application_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=QFLIStudioN
Comment=IDE for many languages, built with Flutter
Exec=$package_name
Icon=$application_id
Terminal=false
Categories=Development;IDE;
StartupWMClass=$application_id
EOF

cp "$icon" "$deb_root/usr/share/pixmaps/$application_id.png"

{
  echo "QFLIStudioN is distributed under the GNU General Public License version 3."
  echo
  echo "=== LICENSE ==="
  cat "$root/LICENSE"
} > "$deb_root/usr/share/doc/$package_name/copyright"

find "$deb_root" -type d -exec chmod 0755 {} +
find "$deb_root" -type f -exec chmod 0644 {} +
chmod 0755 "$deb_root$install_dir/$binary_name" "$deb_root/usr/bin/$package_name"

installed_kib="$(du -sk --exclude=DEBIAN "$deb_root" | cut -f1)"
cat > "$deb_root/DEBIAN/control" <<EOF
Package: $package_name
Version: $version
Architecture: $deb_arch
Maintainer: azurekiln2333 <1665673737@qq.com>
Installed-Size: $installed_kib
Depends: libc6 (>= 2.35), libstdc++6, libgtk-3-0, libglib2.0-0, libsecret-1-0
Section: devel
Priority: optional
Homepage: https://github.com/azurekiln2333/qflistudio-next
Description: QFLIStudioN, an IDE for many languages built with Flutter
 QFLIStudioN edits and runs code for many languages on the device.
 The package is built in CI and is not signed.
EOF

deb_name="qflistudio_${version}_${deb_arch}.deb"
dpkg-deb --build --root-owner-group "$deb_root" "$output/$deb_name" >/dev/null

echo "$output/$tar_name.tar.gz"
echo "$output/$deb_name"
