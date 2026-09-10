#!/bin/bash
#spellchecker: ignore rootfs hostnamectl hostnamed

rootfs="$(install-slices systemd_hostname)"

for bin in /usr/bin/hostnamectl /usr/lib/systemd/systemd-hostnamed; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
