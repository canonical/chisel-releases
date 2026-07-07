#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver libbfd

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "x86_64" || "$arch" == "s390x" ]]; then
    cross=true
elif [[ "$arch" == "ppc64le" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    rootfs="$(install-slices \
        binutils-powerpc64le-linux-gnu_archiver \
        binutils-powerpc64le-linux-gnu_cross-libbfd \
    )"
    ln -s "powerpc64le-linux-gnu-ar" "$rootfs/usr/bin/ar"
else
    rootfs="$(install-slices \
        binutils-powerpc64le-linux-gnu_archiver \
    )"
    ln -s "powerpc64le-linux-gnu-ar" "$rootfs/usr/bin/ar"
fi

touch "$rootfs/file1" "$rootfs/file2"
chroot "$rootfs" ar rcs archive file1 file2
chroot "$rootfs" ar t archive | grep -q "file1"
chroot "$rootfs" ar t archive | grep -q "file2"
