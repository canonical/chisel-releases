#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils coreutils

rootfs="$(install-slices bsdutils_script)"

chroot "$rootfs" /usr/bin/script --help | grep -q "Usage:"
chroot "$rootfs" /usr/bin/script --version | grep -q "script from"

rootfs_printf=$(install-slices bsdutils_script dash_bins)
mkdir -p "$rootfs_printf"/dev && mount --rbind /dev "$rootfs_printf"/dev
trap "umount -l $rootfs_printf/dev || true" EXIT
mkdir -p "$rootfs_printf"/tmp

# test the script with --command
export SHELL=/usr/bin/sh
chroot "$rootfs_printf" /usr/bin/script \
    --log-out /tmp/script.log \
    --command "printf 'hello script --command'" | grep -q "hello script --command"

grep -q "hello script --command" "$rootfs_printf"/tmp/script.log

# test the script with stdin
rm -f "$rootfs_printf"/tmp/script.log "$rootfs_printf"/tmp/script.in
echo -e "printf 'hello script stdin'\nexit" | chroot "$rootfs_printf" /usr/bin/script \
    --log-out /tmp/script.log \
    --log-in /tmp/script.in | grep -q "hello script stdin"

grep -q "hello script stdin" "$rootfs_printf"/tmp/script.log
