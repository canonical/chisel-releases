#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils libbfd libopcodes libctf archiver

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

slices=(
    binutils-"${other//_/-}"_assembler
    binutils-"${other//_/-}"_cross-libbfd
)
if [[ "$this" == "x86_64-linux-gnu" ]]; then
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-"${other//_/-}"_cross-libopcodes)
fi
rootfs_as="$(install-slices "${slices[@]}")"
ln -s "$other-as" "$rootfs_as/usr/bin/as"

chroot "$rootfs_as" as --help | grep -q "Usage: as"
chroot "$rootfs_as" as --version | grep -q "GNU assembler"

slices=(
    binutils-"${other//_/-}"_linker
    binutils-"${other//_/-}"_cross-libbfd
    binutils-"${other//_/-}"_cross-libctf
)
if [[ "$this" == "x86_64-linux-gnu" ]]; then
    # when compiling from x86_64 to aarch64 we also need libopcodes
    slices+=(binutils-"${other//_/-}"_cross-libopcodes)
fi
rootfs_ld="$(install-slices "${slices[@]}")"
ln -s "$other-ld" "$rootfs_ld/usr/bin/ld"

# # NOTE: ld --help blows up in pipefail mode when piped...
(chroot "$rootfs_ld" ld --help || true) | grep -q "Usage: ld"
chroot "$rootfs_ld" ld --version | grep -q "GNU ld"

slices=(
    binutils-"${other//_/-}"_archiver
    binutils-"${other//_/-}"_cross-libbfd
)
rootfs_ar="$(install-slices "${slices[@]}")"
ln -s "$other-ar" "$rootfs_ar/usr/bin/ar"

chroot "$rootfs_ar" ar --help | grep -q "Usage: ar"
chroot "$rootfs_ar" ar --version | grep -q "GNU ar"
