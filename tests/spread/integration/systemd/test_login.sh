#!/bin/bash
#spellchecker: ignore rootfs loginctl logind

rootfs="$(install-slices systemd_login)"

for bin in /usr/bin/loginctl /usr/lib/systemd/systemd-logind; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done

# helpers that insist on specific arguments still prove they load
chroot "$rootfs" /usr/lib/systemd/systemd-user-runtime-dir 2>&1 | grep -Fiq "takes two arguments"
chroot "$rootfs" /usr/lib/systemd/systemd-user-sessions --version 2>&1 | grep -Fiq "Unknown verb"
