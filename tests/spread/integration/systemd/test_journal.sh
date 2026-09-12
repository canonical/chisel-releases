#!/bin/bash
#spellchecker: ignore rootfs journalctl

rootfs="$(install-slices systemd_journal)"

chroot "$rootfs" journalctl --version 2>&1 | grep -Fiq "systemd"

# /var/log/journal is created by the slice but holds no journals yet
chroot "$rootfs" journalctl --no-pager --directory=/var/log/journal 2>&1 \
  | grep -Fiq "No journal files were found"
