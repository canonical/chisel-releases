#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_summarizing-files)"
cmds=(
    b2sum
    cksum
    md5sum
    sha1sum
    sha224sum
    sha256sum
    sha384sum
    sha512sum
    sum
    wc
)
for cmd in "${cmds[@]}"; do
    chroot "$rootfs" "$cmd" --version | grep -q "coreutils"
done
