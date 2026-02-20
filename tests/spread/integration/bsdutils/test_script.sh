#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils coreutils

rootfs="$(install-slices bsdutils_script)"

chroot "$rootfs" /usr/bin/script --help | grep -q "Usage:"
chroot "$rootfs" /usr/bin/script --version | grep -q "script from"

rootfs_echo=$(install-slices bsdutils_script dash_bins)

mkdir -p "$rootfs_echo"/dev && mount --rbind /dev "$rootfs_echo"/dev
trap "umount -l $rootfs_echo/dev || true" EXIT

mkdir -p "$rootfs_echo"/tmp

# test the script command with --log-out and --log-in options, which should work without a terminal and without socket errors
export SHELL=/usr/bin/sh
chroot "$rootfs_echo" /usr/bin/script \
    --log-out /tmp/script.log \
    --command "printf 'hello script'" | grep -q "hello script"

grep -q "hello script" "$rootfs_echo"/tmp/script.log
