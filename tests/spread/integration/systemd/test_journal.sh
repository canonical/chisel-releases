#!/bin/bash
#spellchecker: ignore rootfs journalctl

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_journal)"

assert_version "$rootfs" journalctl
# /var/log/journal is created by the slice but holds no journals yet
out="$(chroot "$rootfs" journalctl --no-pager --directory=/var/log/journal 2>&1)"
grep -Fiq "No journal files were found" <<<"$out"
