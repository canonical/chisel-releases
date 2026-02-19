#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver libbfd

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" ]]; then
    cross=true
elif [[ "$arch" == "x86_64" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    rootfs="$(install-slices \
        binutils-x86-64-linux-gnu_archiver \
        binutils-x86-64-linux-gnu_cross-libbfd \
    )"
    ln -s "x86_64-linux-gnu-ar" "$rootfs/usr/bin/ar"
else
    rootfs="$(install-slices \
        binutils-x86-64-linux-gnu_archiver \
    )"
    ln -s "x86_64-linux-gnu-ar" "$rootfs/usr/bin/ar"
fi

touch "$rootfs/file1" "$rootfs/file2"
chroot "$rootfs" ar rcs archive file1 file2
chroot "$rootfs" ar t archive | grep -q "file1"
chroot "$rootfs" ar t archive | grep -q "file2"