#!/usr/bin/env bash
# spellchecker: ignore rootfs miri resolv

rootfs="$(install-slices rust-1.93-miri_cargo-miri cargo-1.93_cargo ca-certificates_data)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# We need DNS to fetch crates.io dependencies for Miri's sysroot build
mkdir -p "$rootfs/etc" && cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
# shellcheck disable=SC2064
trap "umount '$rootfs/proc'" EXIT

# Create a simple project and run it under Miri
chroot "$rootfs" cargo-1.93 new /hello_miri --bin --vcs none
chroot "$rootfs" /bin/sh -c 'cd /hello_miri && cargo-1.93-unstable-miri run' |
  grep -Fq "Hello, world!"
