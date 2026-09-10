#!/bin/bash
#spellchecker: ignore rootfs timedatectl timedated

rootfs="$(install-slices systemd_timedate)"

for bin in /usr/bin/timedatectl /usr/lib/systemd/systemd-timedated; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
