#!/bin/bash
#spellchecker: ignore rootfs localectl localed

rootfs="$(install-slices systemd_locale)"

for bin in /usr/bin/localectl /usr/lib/systemd/systemd-localed; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
