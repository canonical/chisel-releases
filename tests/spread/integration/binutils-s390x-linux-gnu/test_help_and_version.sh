#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver libbfd libctf libopcodes
set -eu

arch=$(uname -m)
cross=false
if [[ "$arch" == "aarch64" || "$arch" == "x86_64" || "$arch" == "ppc64le" ]]; then
    cross=true
elif [[ "$arch" == "s390x" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    slices=(
        binutils-s390x-linux-gnu_assembler
        binutils-s390x-linux-gnu_cross-libbfd
        binutils-s390x-linux-gnu_cross-libopcodes
    )
    rootfs_as="$(install-slices "${slices[@]}")"
    ln -s "s390x-linux-gnu-as" "$rootfs_as/usr/bin/as"

    slices=(
        binutils-s390x-linux-gnu_linker
        binutils-s390x-linux-gnu_cross-libbfd
        binutils-s390x-linux-gnu_cross-libctf
    )
    rootfs_ld="$(install-slices "${slices[@]}")"
    ln -s "s390x-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"

    slices=(
        binutils-s390x-linux-gnu_archiver
        binutils-s390x-linux-gnu_cross-libbfd
    )
    rootfs_ar="$(install-slices "${slices[@]}")"
    ln -s "s390x-linux-gnu-ar" "$rootfs_ar/usr/bin/ar"
else
    rootfs_as=$(install-slices \
        binutils-s390x-linux-gnu_assembler \
    )
    ln -s "s390x-linux-gnu-as" "$rootfs_as/usr/bin/as"
    rootfs_ld=$(install-slices \
        binutils-s390x-linux-gnu_linker \
    )
    ln -s "s390x-linux-gnu-ld" "$rootfs_ld/usr/bin/ld"
    rootfs_ar=$(install-slices \
        binutils-s390x-linux-gnu_archiver \
    )
    ln -s "s390x-linux-gnu-ar" "$rootfs_ar/usr/bin/ar"
fi


chroot "$rootfs_as" as --help | grep -q "Usage: as"
chroot "$rootfs_as" as --version | grep -q "GNU assembler"
# # NOTE: ld --help blows up in pipefail mode when piped...
(chroot "$rootfs_ld" ld --help || true) | grep -q "Usage: ld"
chroot "$rootfs_ld" ld --version | grep -q "GNU ld"
chroot "$rootfs_ar" ar --help | grep -q "Usage: ar"
chroot "$rootfs_ar" ar --version | grep -q "GNU ar"
