#!/bin/bash
#spellchecker: ignore rootfs dotnetsay

# What a consumer gets from dotnet-host-10.0_dnx: a tool package run straight
# from NuGet, with the SDK underneath to restore it.

rootfs="$(install-slices dotnet-host-10.0_dnx base-passwd_data)"

mkdir -p "$rootfs/proc" "$rootfs/tmp" "$rootfs/dev" "$rootfs/root"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT
# the SDK seeds its random numbers from these
head -c 10000 /dev/urandom > "$rootfs/dev/random"
head -c 10000 /dev/urandom > "$rootfs/dev/urandom"
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

echo "Hello, World!" | DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 HOME=/root \
  chroot "$rootfs" /usr/bin/dnx dotnetsay --yes | grep -Fq "Hello, World!"
