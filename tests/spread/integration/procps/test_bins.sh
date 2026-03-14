#!/usr/bin/env bash
# spellchecker: ignore rootfs

# TODO: subslice and test these properly. for now just run --help and --version on
# every bin in bins

rootfs="$(install-slices procps_bins)"

# mount proc for ps and top tests
mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

bins=(
    free
    kill
    pgrep
    pidwait
    pkill
    pmap
    pwdx
    skill
    slabtop
    snice
    sysctl
    tload
    uptime
    vmstat
    w
    watch
    ps
    top
)

for bin in "${bins[@]}"; do
    chroot "$rootfs" "$bin" --help 2>&1 | grep -iq 'usage:'
    chroot "$rootfs" "$bin" --version 2>&1 | grep -q "$bin from procps-ng"
done
