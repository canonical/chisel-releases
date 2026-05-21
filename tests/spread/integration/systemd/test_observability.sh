#!/bin/bash
#spellchecker: ignore rootfs journalctl networkctl

rootfs="$(install-slices \
  systemd_journal \
  systemd_network)"

chroot "$rootfs" /usr/bin/journalctl --help 2>&1 | grep -Fiq "journalctl"
chroot "$rootfs" /usr/bin/journalctl --version 2>&1 | grep -Fiq "systemd"
chroot "$rootfs" /usr/bin/journalctl --list-boots 2>&1 | grep -Fiq "no journal files"

chroot "$rootfs" /usr/bin/networkctl --help 2>&1 | grep -Fiq "networkctl"
chroot "$rootfs" /usr/bin/networkctl --version 2>&1 | grep -Fiq "systemd"
chroot "$rootfs" /usr/bin/networkctl list 2>&1 | grep -Fiq "failed to connect system bus"
