#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs

rootfs="$(install-slices dpkg_dpkg-deb)"

# Check that dpkg-deb runs and shows help
chroot "${rootfs}/" dpkg-deb --help | grep -q "Usage: dpkg-deb"
version=$(chroot "${rootfs}/" dpkg-deb --version | head -n1 || true)
echo "$version" | grep -q "Debian 'dpkg-deb' package archive backend version"

# Create a sample file to build a .deb package
mkdir -p "$rootfs/foo/DEBIAN"
mkdir -p "$rootfs/foo/usr/local/share"
touch "$rootfs/foo/usr/local/share/foo.txt"

cat > "$rootfs/foo/DEBIAN/control" << EOF
Package: foo
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Maintainer: Test <test@test.com>
Description: A test package containing a dummy file.
EOF

chroot "$rootfs" dpkg-deb --build /foo
test -f "$rootfs/foo.deb"

# Display information about the created .deb package
info=$(chroot "$rootfs" dpkg-deb --info /foo.deb)
echo "$info" | grep -q " new Debian package, version 2.0"
echo "$info" | grep -q " Package: *foo"
echo "$info" | grep -q " Version: *1.0"

# List contents of the created .deb package
chroot "$rootfs" dpkg-deb --contents /foo.deb | grep -q "usr/local/share/foo.txt"

# Extract the contents of the created .deb package to a new directory
mkdir -p "$rootfs/extracted"
chroot "$rootfs" dpkg-deb --extract /foo.deb /extracted
test -f "$rootfs/extracted/usr/local/share/foo.txt"

# Extract the control information of the created .deb package to a new directory
mkdir -p "$rootfs/control"
chroot "$rootfs" dpkg-deb --control /foo.deb /control
test -f "$rootfs/control/control"
cat "$rootfs/control/control" | grep -q "Package: *foo"
cat "$rootfs/control/control" | grep -q "Version: *1.0"

# Show specific fields from the control information of the created .deb package
chroot "$rootfs" dpkg-deb --field /foo.deb Package | grep -q "^foo$"
chroot "$rootfs" dpkg-deb --field /foo.deb Version | grep -q "^1.0$"

# Show information about the created .deb package using dpkg-deb --show
chroot "$rootfs" dpkg-deb --show /foo.deb | grep -q "foo\s\+1.0"
