#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs binutils archiver libbfd

this=$(uname -m)
if [[ "$this" == "x86_64" ]]; then
    other="aarch64"
elif [[ "$this" == "aarch64" ]]; then
    other="x86_64"
else
    echo "Unsupported architecture: $this"
    exit 1
fi

this="$this-linux-gnu"
other="$other-linux-gnu"


rootfs="$(install-slices \
    binutils-"${other//_/-}"_archiver \
    binutils-"${other//_/-}"_cross-libbfd \
)"
ln -s "$other-ar" "$rootfs/usr/bin/ar"

touch "$rootfs/file1" "$rootfs/file2"
chroot "$rootfs" ar rcs archive file1 file2
chroot "$rootfs" ar t archive | grep -q "file1"
chroot "$rootfs" ar t archive | grep -q "file2"
