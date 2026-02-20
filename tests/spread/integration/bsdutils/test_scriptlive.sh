#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils scriptlive

rootfs="$(install-slices bsdutils_scriptlive)"

chroot "$rootfs" /usr/bin/scriptlive --help | grep -q "Usage:"
chroot "$rootfs" /usr/bin/scriptlive --version | grep -q "scriptlive from"

rootfs_echo=$(install-slices bsdutils_scriptlive coreutils_echo)
mkdir -p "$rootfs_echo"/dev && mount --rbind /dev "$rootfs_echo"/dev
trap "umount -l $rootfs_echo/dev || true" EXIT

export SHELL=/usr/bin/sh
chroot "$rootfs_echo" /usr/bin/scriptlive \
    --log-out /tmp/scriptlive.log \
    --command "printf 'hello scriptlive'" | grep -q "hello scriptlive"
grep -q "hello scriptlive" "$rootfs_echo"/tmp/scriptlive.log
