#!/bin/bash
#spellchecker: ignore rootfs dpkg

rootfs="$(install-slices dpkg_db-backup)"

mkdir -p "$rootfs/dev" "$rootfs/var/backups" "$rootfs/var/lib/dpkg/alternatives"
# the script sends its tool checks and tar output to /dev/null
touch "$rootfs/dev/null"
echo "Package: example" > "$rootfs/var/lib/dpkg/status"
chroot "$rootfs" /usr/libexec/dpkg/dpkg-db-backup

grep -qx "Package: example" "$rootfs/var/backups/dpkg.status.0"
test -s "$rootfs/var/backups/alternatives.tar.0"
