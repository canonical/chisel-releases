#!/bin/bash
#spellchecker: ignore rootfs tmpfiles

# What systemd_user-services ships for a user manager: its units, and the
# programs they run, which load from the slice alone.

rootfs="$(install-slices systemd_user-services)"
for bin in /usr/bin/systemd-ask-password /usr/bin/systemd-tmpfiles; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done
