#!/usr/bin/env bash
# spellchecker: ignore rootfs miri resolv

rootfs="$(install-slices rust-miri_cargo-miri ca-certificates_data)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# We need DNS to fetch crates.io dependencies for Miri's sysroot build
mkdir -p "$rootfs/etc" && cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
# shellcheck disable=SC2064
trap "umount '$rootfs/proc'" EXIT

cp -r testfiles/hello_ub "$rootfs"

# Miri exits non-zero once it reports undefined behaviour, which is the
# outcome under test here
output="$(chroot "$rootfs" /bin/sh -c 'cd /hello_ub && cargo-unstable-miri run' 2>&1 || true)"
grep -Fiq 'undefined behavior' <<<"$output"
