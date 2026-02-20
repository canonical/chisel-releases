#!/usr/bin/env bash
#spellchecker: ignore rootfs

rootfs="$(install-slices bsdutils_bins)"

# needs dev/run (definitely not normally ok) mounted
mkdir -p "$rootfs"/dev && mount --rbind /dev "$rootfs"/dev
mkdir -p "$rootfs"/run && mount --rbind /run "$rootfs"/run

cleanup() {
    umount -l "$rootfs"/run || true
    umount -l "$rootfs"/dev || true
}

trap cleanup EXIT

# smoke test the logger binary
chroot "$rootfs" /usr/bin/logger "hello from spread"

# should now be visible in journal
journalctl -b | grep "hello from spread"
